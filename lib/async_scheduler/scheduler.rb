module AsyncScheduler
  # This class implements Fiber::SchedulerInterface.
  # See https://ruby-doc.org/core-3.1.0/Fiber/SchedulerInterface.html for details.
  class Scheduler
    def initialize
      # (key, value) = (Fiber object, timeout)
      @waitings = {}
      # (key, value) = (blocking io, Fiber object)
      @input_waitings = {}
      @output_waitings = {}
      # number of blockers which blocks for good. e.g. sleeping without the timeout.
      @blocking_cnt = 0
    end


    # Implementation of the Fiber.schedule.
    # The method is expected to immediately run the given block of code in a separate non-blocking fiber,
    # and to return that Fiber.
    def fiber(&block)
      fiber = Fiber.new(blocking: false, &block)
      fiber.resume
      fiber
    end

    # Invoked by methods like Thread.join, and by Mutex, to signify that current Fiber is blocked until further notice (e.g. unblock) or until timeout has elapsed.
    # blocker is what we are waiting on, informational only (for debugging and logging). There are no guarantee about its value.
    # Expected to return boolean, specifying whether the blocking operation was successful or not.
    def block(blocker, timeout = nil)
      @waitings[Fiber.current] = timeout
      return true
    end

    # Invoked to wake up Fiber previously blocked with block (for example, Mutex#lock calls block and Mutex#unlock calls unblock).
    # The scheduler should use the fiber parameter to understand which fiber is unblocked.
    # blocker is what was awaited for, but it is informational only (for debugging and logging),
    # and it is not guaranteed to be the same value as the blocker for block.
    def unblock(blocker, fiber)
      fiber.resume
    end

    # Invoked by Kernel#sleep and Mutex#sleep and is expected to provide an implementation of sleeping in a non-blocking way.
    # Implementation might register the current fiber in some list of “which fiber wait until what moment”,
    # call Fiber.yield to pass control, and then in close resume the fibers whose wait period has elapsed.
    def kernel_sleep(duration = nil)
      if duration
        block(:kernel_sleep, Time.now + duration)
        Fiber.yield
      else
        @blocking_cnt += 1
      end
    end

    # Invoked by Timeout.timeout to execute the given block within the given duration.
    # It can also be invoked directly by the scheduler or user code.
    # Attempt to limit the execution time of a given block to the given duration if possible.
    # When a non-blocking operation causes the block's execution time to exceed the specified duration, that non-blocking operation should be interrupted by raising the specified exception_class constructed with the given exception_arguments.
    # General execution timeouts are often considered risky.
    # This implementation will only interrupt non-blocking operations.
    # This is by design because it's expected that non-blocking operations can fail for a variety of unpredictable reasons, so applications should already be robust in handling these conditions and by implication timeouts.
    # However, as a result of this design, if the block does not invoke any non-blocking operations, it will be impossible to interrupt it. If you desire to provide predictable points for timeouts, consider adding +sleep(0)+.
    # If the block is executed successfully, its result will be returned.
    # The exception will typically be raised using Fiber#raise.
    def timeout_after(duration, exception_class, *exception_arguments, &block) # → result of block
    end

    # Called when the current thread exits. The scheduler is expected to implement this method in order to allow all waiting fibers to finalize their execution.
    # The suggested pattern is to implement the main event loop in the close method.
    def close
      while !@waitings.empty? || @blocking_cnt > 0 || !@output_waitings.empty?
        while !@waitings.empty?
          first_fiber, first_timeout = @waitings.min_by{|fiber, timeout| timeout}
          break if Time.now < first_timeout
          unblock(:_closed_fiber, first_fiber) # TODO: pass a good named identifier of the fiber
          @waitings.delete(first_fiber)
        end

        while !@output_waitings.empty?
          _input_ready, output_ready = IO.select([], @output_waitings.keys)
          fiber_non_blocking = @output_waitings[output_ready]
          fiber_non_blocking.resume
        end
      end
    end


    # Invoked by IO#wait, IO#wait_readable, IO#wait_writable to ask whether the specified descriptor is ready for specified events within the specified timeout.
    # events is a bit mask of IO::READABLE, IO::WRITABLE, and IO::PRIORITY.

    # Suggested implementation should register which Fiber is waiting for which resources and immediately calling Fiber.yield to pass control to other fibers.
    # Then, in the close method, the scheduler might dispatch all the I/O resources to fibers waiting for it.
    # Expected to return the subset of events that are ready immediately.
    def io_wait(io, events, _timeout)
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

    def io_read(io, buffer, length) # read length or -errno
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
      result = io.write_nonblock(buffer, exception: false)
      case result
      when :wait_writable
        # TODO: this may not write all bytes in buffer to io.
        # See: https://docs.ruby-lang.org/ja/latest/class/IO.html#I_WRITE_NONBLOCK
        io_wait(io, IO::WRITABLE, nil)
      else
        return result
      end
    end
  end
end
