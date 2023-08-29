# frozen_string_literal: true
require 'socket'
require 'resolv'

RSpec.describe AsyncScheduler do
  describe "DNS resolution" do
    def resolve_address_with_scheduler(hostname, port)
      Thread.new do
        scheduler = AsyncScheduler::Scheduler.new
        Fiber.set_scheduler scheduler
        ips = nil
        Fiber.schedule do
          ips = Socket.getaddrinfo(hostname, port)
        end
        scheduler.close
        ips
      end.value
    end

    it "resolves localhost successfully" do
      expect(resolve_address_with_scheduler("localhost", 443)).to contain_exactly(
        ["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 1, 6],
        ["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 2, 17],
        ["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 3, 0],
        ["AF_INET6", 443, "::1", "::1", 30, 1, 6],
        ["AF_INET6", 443, "::1", "::1", 30, 2, 17],
        ["AF_INET6", 443, "::1", "::1", 30, 3, 0]
      )
    end

    it "resolves localhost successfully" do
      expect(resolve_address_with_scheduler("localhost", 80)).to contain_exactly(
        ["AF_INET", 80, "127.0.0.1", "127.0.0.1", 2, 1, 6],
        ["AF_INET", 80, "127.0.0.1", "127.0.0.1", 2, 2, 17],
        ["AF_INET", 80, "127.0.0.1", "127.0.0.1", 2, 3, 0],
        ["AF_INET6", 80, "::1", "::1", 30, 1, 6],
        ["AF_INET6", 80, "::1", "::1", 30, 2, 17],
        ["AF_INET6", 80, "::1", "::1", 30, 3, 0]
      )
    end

    it "resolves google.com successfully" do
      address_infos = resolve_address_with_scheduler("google.com", 443)
      ips = address_infos.map{|ai| ai[2]}.uniq
      expect(ips.length).to eq(2) # IPv4 and IPv6

      expect(address_infos).to contain_exactly(
        ["AF_INET", 443, ips[0], ips[0], 2, 1, 6],
        ["AF_INET", 443, ips[0], ips[0], 2, 2, 17],
        ["AF_INET", 443, ips[0], ips[0], 2, 3, 0],
        ["AF_INET6", 443, ips[1], ips[1], 30, 1, 6],
        ["AF_INET6", 443, ips[1], ips[1], 30, 2, 17],
        ["AF_INET6", 443, ips[1], ips[1], 30, 3, 0]
      )
    end

    it "resolves google.com successfully" do
      address_infos = resolve_address_with_scheduler("google.com", 80)
      ips = address_infos.map{|ai| ai[2]}.uniq
      expect(ips.length).to eq(2) # IPv4 and IPv6

      # NOTE: This does not check if ips are really those of google.com.
      expect(address_infos).to contain_exactly(
        ["AF_INET", 80, ips[0], ips[0], 2, 1, 6],
        ["AF_INET", 80, ips[0], ips[0], 2, 2, 17],
        ["AF_INET", 80, ips[0], ips[0], 2, 3, 0],
        ["AF_INET6", 80, ips[1], ips[1], 30, 1, 6],
        ["AF_INET6", 80, ips[1], ips[1], 30, 2, 17],
        ["AF_INET6", 80, ips[1], ips[1], 30, 3, 0]
      )
    end
  end

  describe "DNS resolution performance" do
    def resolve_address_with_scheduler(hostname, port, num_times)
      Thread.new do
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        scheduler = AsyncScheduler::Scheduler.new
        Fiber.set_scheduler AsyncScheduler::Scheduler.new

        num_times.times do
          Fiber.schedule do
            Socket.getaddrinfo("www.google.com", 443)
          end
        end

        scheduler.close
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
      end.value
    end

    def resolve_address_with_multithreads(hostname, port, num_times)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      num_times.times do
        Thread.new do
          Socket.getaddrinfo("www.google.com", 443)
        end.join
      end
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
    end

    it "resolves addresses in a Fiber.schedule block" do
      puts "👁  Confirm these things."
      puts "- Resolving with scheduler is faster than multithreading."
      puts "- Execution times of resolving scheduler do not improve in a liner manner."

      ["localhost", "google.com"].each do |hostname|
        puts "--------------------------"
        puts "|   Resolve #{hostname.ljust(10)}   |"
        puts "--------------------------"

        [1, 10, 100].each do |num_times|
          puts "## Resolving #{num_times} times:"
          puts "Resolve with scheduler:    #{resolve_address_with_scheduler(hostname, 443, num_times)}"
          puts "Resolve with multithreads: #{resolve_address_with_multithreads(hostname, 443, num_times)}"
          puts
        end
      end
    end
  end
end
