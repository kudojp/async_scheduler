# frozen_string_literal: true
require 'socket'

RSpec.describe AsyncScheduler do
  it "resolves addresses in a Fiber.schedule block" do
    t = Time.now
    params = [1, 10, 100]

    params.each do |num|
      t = Time.now
      thread = Thread.new do
        Fiber.set_scheduler AsyncScheduler::Scheduler.new

        num.times do
          Fiber.schedule do
            Socket.getaddrinfo("www.google.com", 443)
          end
        end
      end
      thread.join
      puts "#{Time.now - t} seconds for resolving #{num} hostname."
    end
  end
end
