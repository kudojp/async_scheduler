# frozen_string_literal: true

require 'async_scheduler/cross_thread_usage_detector'

RSpec.describe AsyncScheduler do
  it "can create and run a new thread in a Fiber.schedule block" do
    parent_thread = Thread.new do
      Fiber.set_scheduler AsyncScheduler::Scheduler.new
      Fiber.schedule do
        $child_thread = Thread.new {}
        $child_thread.join
      end
    end

    begin
      parent_thread.join
      raise Exception.new("This should not be reached")
    rescue => e
      expect(e.class).to eq(CrossThreadUsageDetector::CrossThreadUsageError)
      expect(e.message).to eq("Cross-thread usage detected. FiberScheduler was originally registered to a thread (#{parent_thread.object_id}), but it is attempted to be used in another thread (#{$child_thread.object_id}).")
    end

    # NOTE: the reason why I don't use the following code is because:
    #       `#{$child_thread.object_id}` in the matcher seems to be evaluated before `parent_thread.join` finishes.
    #       When this occurs, $child_thread.object_id is not set yet and it is evaluated as 8, which is object_id of nil.
    #
    # expect { parent_thread.join }.to raise_error(
    #   CrossThreadUsageDetector::CrossThreadUsageError,
    #   "Cross-thread usage detected. FiberScheduler was originally registered to a thread (#{parent_thread.object_id}), but it is attempted to be used in another thread (#{$child_thread.object_id})."
    # )
  end
end
