# frozen_string_literal: true
require 'socket'

RSpec.describe AsyncScheduler do
  it "resolves addresses in a Fiber.schedule block" do
    puts "###### TODO! Confirm that times below does not improve in a liner manner."

    t = Time.now
    params = [1, 10, 100, 1000]

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

  it "resolves an address into IP and the result is the same as that in a synchronous manner " do
    thread_resolving_address = Thread.new do
      Fiber.set_scheduler AsyncScheduler::Scheduler.new

      ips = nil
      Fiber.schedule do
        ips = Socket.getaddrinfo("www.google.com", 443)
      end
      ips
    end

    # NOTE: This test case could be flaky, because IP addresses mapped from "www.google.com" could change.
    expect(thread_resolving_address.value).to contain_exactly Socket.getaddrinfo("www.google.com", 443)
  end
end
