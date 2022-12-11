# frozen_string_literal: true

require 'async_scheduler/cross_thread_usage_detector'

RSpec.describe AsyncScheduler do
  it "can create and run a new thread in a Fiber.schedule block" do
    Thread.abort_on_exception = false

    parent_thread = Thread.new do
      Fiber.set_scheduler AsyncScheduler::Scheduler.new
      Fiber.schedule do
        $child_thread = Thread.new {}
        $child_thread.join
      end
    end

    expect { parent_thread.join }.to raise_error(
      CrossThreadUsageDetector::CrossThreadUsageError,
      "Cross-thread usage detected. FiberScheduler was originally registered to a thread (#{parent_thread.object_id}), but it is attempted to be used in another thread (#{$child_thread.object_id})."
    )
  end
end
