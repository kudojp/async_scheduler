module AsyncScheduler
  # This class implements Fiber::SchedulerInterface.
  # See https://ruby-doc.org/core-3.1.0/Fiber/SchedulerInterface.html for details.
  class Scheduler
    def initialize
      # (key, value) = (Fiber object, timeout)
      @waitings = {}
      # number of blockers which blocks for good.
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
      @waiting[Fiber.current] = timeout
      return true
    end

    # Invoked to wake up Fiber previously blocked with block (for example, Mutex#lock calls block and Mutex#unlock calls unblock).
    # The scheduler should use the fiber parameter to understand which fiber is unblocked.
    # blocker is what was awaited for, but it is informational only (for debugging and logging),
    # and it is not guaranteed to be the same value as the blocker for block.
    def unblock(blocker, fiber)
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
    end

    def io_wait
    end

    def io_read
    end

    def io_write(_, _, _)
    end
  end
end
