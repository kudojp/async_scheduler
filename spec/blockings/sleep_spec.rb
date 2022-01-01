# frozen_string_literal: true

RSpec.describe AsyncScheduler do
  before do
  end

  it "sleeps in fibers with AsyncScheduler::Scheduler" do
    t = Time.now
    thread = Thread.new do
      t = Time.now
      Fiber.set_scheduler AsyncScheduler::Scheduler.new

      Fiber.schedule do
        sleep(3)
      end
      Fiber.schedule do
        sleep(3)
      end
      Fiber.schedule do
        sleep(3)
      end

    end
    thread.join
    # This method should take around 3 seconds, not around 9 seconds.
    puts "It took #{Time.now - t} seconds to run three fibers concurrently."
  end
end
