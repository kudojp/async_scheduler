require 'set'
require 'resolv_fiber'
require_relative './cross_thread_usage_detector'

module AsyncScheduler
  # This class implements Fiber::SchedulerInterface.
  # See https://ruby-doc.org/core-3.1.0/Fiber/SchedulerInterface.html for details.
  class Scheduler
    include CrossThreadUsageDetector

    def initialize
      set_belonging_thread!

      # (key, value) = (Fiber object, timeout<not nil>)
      @waitings = {}
      # (key, value) = (blocking io, Fiber object)
      @input_waitings = {}
      @output_waitings = {}
      # Fibers which are blocking and whose timeouts are not determined.
      # e.g. Fiber which includes sleep()
      @blockings = Set.new()
      # (key, value) = (socket, Hash{:blocked_fiber => <Fiber object>, :timeout => <timeout>})
      @blocking_sockets = {}
      # NOTE: When either of the sockets(value) is ready, the fiber(key) can be resumed.
      @fiber_to_all_blocker_sockets = Hash.new{|h, fiber| h[fiber] = Set.new}
    end

    # Implementation of the Fiber.schedule.
    # The method is expected to immediately run the given block of code in a separate non-blocking fiber,
    # and to return that Fiber.
    def fiber(&block)
      validate_used_in_original_thread!

      fiber = Fiber.new(blocking: false, &block)
      fiber.resume
      fiber
    end

    # Invoked by methods like Thread.join, and by Mutex, to signify that current Fiber is blocked until further notice (e.g. unblock) or until timeout has elapsed.
    # blocker is what we are waiting on, informational only (for debugging and logging). There are no guarantee about its value.
    # Expected to return boolean, specifying whether the blocking operation was successful or not.
    def block(blocker, timeout = nil)
      validate_used_in_original_thread!

      # TODO: Make use of blocker.
      if timeout
        @waitings[Fiber.current] = timeout
      else
        @blockings << Fiber.current
      end

      true
    end

    # Invoked to wake up Fiber previously blocked with block (for example, Mutex#lock calls block and Mutex#unlock calls unblock).
    # The scheduler should use the fiber parameter to understand which fiber is unblocked.
    # blocker is what was awaited for, but it is informational only (for debugging and logging),
    # and it is not guaranteed to be the same value as the blocker for block.
    def unblock(blocker, fiber)
      validate_used_in_original_thread!

      # TODO: Make use of blocker.
      @blockings.delete fiber
      fiber.resume
    end

    # Invoked by Kernel#sleep and Mutex#sleep and is expected to provide an implementation of sleeping in a non-blocking way.
    # Implementation might register the current fiber in some list of “which fiber wait until what moment”,
    # call Fiber.yield to pass control, and then in close resume the fibers whose wait period has elapsed.
    def kernel_sleep(duration = nil)
      validate_used_in_original_thread!

      timeout = duration ? Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration : nil
      if block(:kernel_sleep, timeout)
        Fiber.yield
      else
        raise RuntimeError.new("Failed to sleep")
      end
    end

    # Invoked by Timeout.timeout to execute the given block within the given duration.
    # It can also be invoked directly by the scheduler or user code.
    #
    # This implementation will only interrupt non-blocking operations.
    # If the block is executed successfully, its result will be returned.
    def timeout_after(duration, exception_class, *exception_arguments, &block) # → result of block
      validate_used_in_original_thread!

      current_fiber = Fiber.current

      if duration
        self.fiber() do
          sleep(duration)
          if current_fiber.alive?
            current_fiber.raise(exception_class, *exception_arguments)
          end
        end
      end

      yield duration
    end

    # Called when the current thread exits. The scheduler is expected to implement this method in order to allow all waiting fibers to finalize their execution.
    # The suggested pattern is to implement the main event loop in the close method.
    def close
      validate_used_in_original_thread!

      while !@waitings.empty? || !@blockings.empty? || !@input_waitings.empty? || !@output_waitings.empty? || !@blocking_sockets.empty?
        # For blocking I/Os...
        while !@input_waitings.empty? || !@output_waitings.empty? || !@blocking_sockets.empty?
          soonest_timeout_ = self.soonest_timeout
          select_duration =
            if soonest_timeout_.nil?
              nil
            else
              duration = soonest_timeout_ - Process.clock_gettime(Process::CLOCK_MONOTONIC)
              # duration here should be very close to 0 even if it is negative.
              [duration, 0].max
            end

          # NOTE: IO.select will keep blocking until timeout even if any new event is added to @waitings.
          # TODO: Don't wait for the input  ready when the corresponding fiber gets terminated, and when it is the only one in @input_waitings.
          # TODO: Don't wait for the output ready when the corresponding fiber gets terminated, and when it is the only one in @output_waitings.
          inputs_ready, outputs_ready = IO.select(
            @input_waitings.keys + @blocking_sockets.keys,
            @output_waitings.keys,
            [],
            select_duration
          )

          inputs_ready&.each do |input|
            if @input_waitings[input]
              fiber_non_blocking = @input_waitings.delete(input)
              fiber_non_blocking.resume if fiber_non_blocking.alive?
            elsif @blocking_sockets[input]
              fiber = @blocking_sockets.delete(input).fetch(:blocked_fiber)
              # ref. comment in #address_resolve
              @fiber_to_all_blocker_sockets.fetch(fiber).each do |socket|
                @blocking_sockets.delete(socket)
              end
              fiber.resume
            else
              raise
            end
          end

          current_clock_monotonic_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          timeout_sockets = @blocking_sockets.select{|socket, blocked| blocked.fetch(:timeout) && (blocked.fetch(:timeout) <= current_clock_monotonic_time)}.keys
          # NOTE: timeout_sockets is nil when there is no rejected element.
          @blocking_sockets.reject!{|socket| timeout_sockets&.include? socket}
          timeout_sockets&.each do |socket|
            @fiber_to_all_blocker_sockets.fetch(fiber).delete(socket)
            fiber.resume if @fiber_to_all_blocker_sockets.fetch(fiber).empty? && fiber.alive?
          end

          outputs_ready&.each do |output|
            fiber_non_blocking = @output_waitings.delete(output)
            fiber_non_blocking.resume if fiber_non_blocking.alive?
          end
        end

        unless @waitings.empty?
          # TODO: Use a min heap for @waitings
          resumable_fibers = @waitings.select{|_fiber, timeout| timeout <= Process.clock_gettime(Process::CLOCK_MONOTONIC)}
                                      .map{|fiber, _timeout| fiber}
                                      .to_set
          resumable_fibers.each{|fiber| fiber.resume if fiber.alive?}
          @waitings.reject!{|fiber, _timeout| resumable_fibers.include? fiber}
        end

        # Unfortunately, current scheduler is unfair to @blockings. Even if any of @blockings is ready, current scheduler has no way to notice it.
        @blockings.select!{|fiber| fiber.alive?}
      end
    end

    def soonest_timeout
      waitings_earliest_timeout = @waitings.empty? ? nil : @waitings.min_by{|fiber, timeout| timeout}[1]
      blocking_socket_earliest_timeout = @blocking_sockets.select{|_socket, blocked| blocked.fetch(:timeout)}.values.min_by{|blocked| blocked.fetch(:timeout)}[0]&.fetch(:timeout)

      if waitings_earliest_timeout && blocking_socket_earliest_timeout
        return [waitings_earliest_timeout, blocking_socket_earliest_timeout].min
      end

      waitings_earliest_timeout || blocking_socket_earliest_timeout
    end
    private_methods :soonest_timeout

    # Invoked by IO#wait, IO#wait_readable, IO#wait_writable to ask whether the specified descriptor is ready for specified events within the specified timeout.
    # events is a bit mask of IO::READABLE, IO::WRITABLE, and IO::PRIORITY.

    # Suggested implementation should register which Fiber is waiting for which resources and immediately calling Fiber.yield to pass control to other fibers.
    # Then, in the close method, the scheduler might dispatch all the I/O resources to fibers waiting for it.
    # Expected to return the subset of events that are ready immediately.
    def io_wait(io, events, _timeout)
      validate_used_in_original_thread!

      # TODO: use timeout parameter
      # TODO?: Expected to return the subset of events that are ready immediately.

      if events & IO::READABLE == IO::READABLE
        @input_waitings[io] = Fiber.current
      end

      if events & IO::WRITABLE == IO::WRITABLE
        @output_waitings[io] = Fiber.current
      end

      Fiber.yield
    end

    # Invoked by IO#read to read length bytes from io into a specified buffer (see IO::Buffer).
    # The length argument is the “minimum length to be read”. If the IO buffer size is 8KiB, but the length is 1024 (1KiB), up to 8KiB might be read, but at least 1KiB will be.
    # Generally, the only case where less data than length will be read is if there is an error reading the data.
    # Specifying a length of 0 is valid and means try reading at least once and return any available data.

    # Suggested implementation should try to read from io in a non-blocking manner and call io_wait if the io is not ready (which will yield control to other fibers).
    # See IO::Buffer for an interface available to return data.
    # Expected to return number of bytes read, or, in case of an error, -errno (negated number corresponding to system's error code).
    def io_read(io, buffer, length) # return length or -errno
      validate_used_in_original_thread!

      read_string = ""
      offset = 0
      while offset < length || length == 0
        read_nonblock = Fiber.new(blocking: true) do
          # AsyncScheduler::Scheduler#io_read is hooked to IO#read_nonblock.
          # To avoid an infinite call loop, IO#read_nonblock is called inside a Fiber whose blocking=true.
          # ref. https://docs.ruby-lang.org/ja/latest/method/IO/i/read_nonblock.html
          io.read_nonblock(buffer.size-offset, read_string, exception: false)
        end

        begin
          # This fiber is resumed only here.
          result = read_nonblock.resume
        rescue SystemCallError => e
          return -e.errno
        end

        case result
        when :wait_readable
          io_wait(io, IO::READABLE, nil)
        when nil # when reaching EOF
          # TODO: Investigate if it is expected to break here.
          break
        else
          offset += buffer.set_string(read_string, offset) # this does not work with `#set_string(result)`
          break if length == 0
        end
      end
      return offset
    end

    # Invoked by IO#write to write length bytes to io from from a specified buffer (see IO::Buffer).
    # The length argument is the “(minimum) length to be written”.
    # If the IO buffer size is 8KiB, but the length specified is 1024 (1KiB), at most 8KiB will be written, but at least 1KiB will be.
    # Generally, the only case where less data than length will be written is if there is an error writing the data.

    # Specifying a length of 0 is valid and means try writing at least once, as much data as possible.
    # Suggested implementation should try to write to io in a non-blocking manner and call io_wait if the io is not ready (which will yield control to other fibers).
    # See IO::Buffer for an interface available to get data from buffer efficiently.
    # Expected to return number of bytes written, or, in case of an error, -errno (negated number corresponding to system's error code).
    def io_write(io, buffer, length) # returns: written length or -errnoclick to toggle source
      validate_used_in_original_thread!

      offset = 0

      while offset < length || length == 0
        write_nonblock = Fiber.new(blocking: true) do
          # TODO: Investigate if this #write_nonblock method call should be in a non-blocking fiber.
          # IO#read_nonblock is hooked to Scheduler#io_wait, so it has to be wrapped.
          # If IO#read_nonblock is hooked to Scheduler#io_read, this method call has to be wrapped too.
          # ref. https://docs.ruby-lang.org/ja/latest/class/IO.html#I_WRITE_NONBLOCK
          io.write_nonblock(buffer.get_string(offset), exception: false)
        end

        begin
          result = write_nonblock.resume
        rescue SystemCallError => e
          return -e.errno
        end

        case result
        when :wait_writable
          io_wait(io, IO::WRITABLE, nil)
        else
          offset += result
          break if length == 0 # Specification says it tries writing at least once if length == 0
        end
      end
      return offset
    end

    # Invoked by any method that performs a non-reverse DNS lookup. (e.g. Addrinfo.getaddrinfo)
    # The method is expected to return an array of strings corresponding to ip addresses the hostname is resolved to, or nil if it can not be resolved.
    def address_resolve(hostname)
      # NOTE:
      # Asynchronous DNS lookup is slower than sequential DNS lookup in a single thread in my experiment.
      # Remove #address_resolve when this scheduler is used in a performance critical application.
      # Run $ `bundle exec rspec spec/blockings/address_resolve_spec.rb` to confirm it.

      validate_used_in_original_thread!
      fiber = ::ResolvFiber.getaddresses_fiber(hostname)
      # Fiber.yield inside of this fiber is located in the loop and may be called multiple times.
      # So here in the caller, the fiber has to be resumed multiple times till the fiber becomes terminated.
      loop do
        result = fiber.resume
        return result unless fiber.alive?

        socks, timeout = result
        # In my experiment, socks here are:
        # - socket to connect to the DNS server which has IPv4 address
        # - socket to connect to the DNS server which has IPv6 address
        # When either of these is ready, DNS resolution is done.
        socks.each do |sock|
          # Fiber.current is blocked by multiple sockets in this way:
          #    @blocking_sockets = {
          #       first_socket:  { blocked_fiber: Fiber.current, timeout: 1111 },
          #       second_socket: { blocked_fiber: Fiber.current, timeout: 1111 },
          #    }
          # If first_socket is ready, both of `first_socket` and `second_socket` must be removed from @blocking_sockets before the fiber gets resumed.
          # (@fiber_to_all_blocker_sockets is used to realize this.)
          # Otherwise, when second_socket is ready, `Fiber.current` will be resumed again unexpectedly.
          # Same thing can be said if second_socket is ready first.
          @blocking_sockets[sock] = {
            blocked_fiber: Fiber.current,
            timeout: timeout,
          }
          @fiber_to_all_blocker_sockets[Fiber.current] << sock
        end

        Fiber.yield
      end
    end
  end
end
