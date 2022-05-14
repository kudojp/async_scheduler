# frozen_string_literal: true

RSpec.describe AsyncScheduler do
  it "can create and run a new thread in a Fiber.schedule block" do
    Thread.abort_on_exception = false
    thread = Thread.new do
      Fiber.set_scheduler AsyncScheduler::Scheduler.new
      Fiber.schedule do
        Thread.new{}.join
      end
    end

    expect{thread.join}.not_to raise_error
  end
end
