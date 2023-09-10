# frozen_string_literal: true
require 'socket'
require 'resolv'

RSpec.describe AsyncScheduler do
  describe "DNS resolution" do
    def resolve_address_with_scheduler(hostname, port, family=nil, socket_type=nil)
      Thread.new do
        scheduler = AsyncScheduler::Scheduler.new
        Fiber.set_scheduler scheduler
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ips = nil
        Fiber.schedule do
          ips = Socket.getaddrinfo(hostname, port, family=family, socket_type=socket_type)
        end
        scheduler.close
        puts "Took: #{Process.clock_gettime(Process::CLOCK_MONOTONIC) - t} seconds"
        ips
      end.value
    end

    it "resolves localhost successfully" do
      # NOTE:
      # Value of Socket::Constants::AF_INET6 seems to differ according to the OS.
      # - Linux: 10
      # - MacOS: 30
      # Thus, it is not hard-coded in tests below.
      puts "#### Resolving (localhost, 443)"
      expect(resolve_address_with_scheduler("localhost", 443)).to contain_exactly(
        ["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 1, 6],
        ["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 2, 17],
        ["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 3, 0],
        ["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 1, 6],
        ["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 2, 17],
        ["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 3, 0],
      )
      puts "### Resolving (localhost, 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_STREAM)"
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_STREAM)).to contain_exactly(["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 1, 6])
      puts
      puts "### Resolving (localhost, 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_DGRAM)"
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_DGRAM)).to contain_exactly(["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 2, 17])
      puts
      puts "### Resolving (localhost, 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_RAW)"
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_RAW)).to contain_exactly(["AF_INET", 443, "127.0.0.1", "127.0.0.1", 2, 3, 0])
      puts
      puts "### Resolving (localhost, 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_STREAM)"
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_STREAM)).to contain_exactly(["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 1, 6])
      puts
      puts "### Resolving (localhost, 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_DGRAM)"
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_DGRAM)).to contain_exactly(["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 2, 17])
      puts
      puts "### Resolving (localhost, 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_RAW)"
      expect(resolve_address_with_scheduler("localhost", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_RAW)).to contain_exactly(["AF_INET6", 443, "::1", "::1", Socket::Constants::AF_INET6, 3, 0])
      puts
    end

    it "resolves google.com successfully" do
      puts "### Resolving (google.com, 443)"
      address_info = resolve_address_with_scheduler("google.com", 443)
      print  "addresses: ", address_info, "\n\n"

      puts "### Resolving (google.com, 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_STREAM)"
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_STREAM)
      # NOTE: It does not check if this IP is really google.com.
      ipv4 = address_info[0][2]
      expect(ipv4).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      expect(address_info).to include(["AF_INET", 443, ipv4, ipv4, 2, 1, 6])
      print address_info, "\n\n"

      puts "### Resolving (google.com, 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_DGRAM)"
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_DGRAM)
      ipv4 = address_info[0][2]
      expect(ipv4).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      expect(address_info).to include(["AF_INET", 443, ipv4, ipv4, 2, 2, 17])
      print address_info, "\n\n"

      puts "### Resolving (google.com, 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_RAW)"
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET, socket_type=Socket::Constants::SOCK_RAW)
      ipv4 = address_info[0][2]
      expect(ipv4).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      expect(address_info).to include(["AF_INET", 443, ipv4, ipv4, 2, 3, 0])
      print address_info, "\n\n"

      puts "### Resolving (google.com, 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_STREAM)"
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_STREAM)
      ipv6 = address_info[0][2]
      # NOTE: there could be multiple resolved IPv6 addresses.
      expect(address_info).to include(["AF_INET6", 443, ipv6, ipv6, Socket::Constants::AF_INET6, 1, 6])
      print address_info, "\n\n"

      puts "### Resolving (google.com, 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_DGRAM)"
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_DGRAM)
      ipv6 = address_info[0][2]
      expect(address_info).to include(["AF_INET6", 443, ipv6, ipv6, Socket::Constants::AF_INET6, 2, 17])
      print address_info, "\n\n"

      puts "### Resolving (google.com, 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_RAW)"
      address_info = resolve_address_with_scheduler("google.com", 443, family=Socket::Constants::AF_INET6, socket_type=Socket::Constants::SOCK_RAW)
      ipv6 = address_info[0][2]
      expect(address_info).to include(["AF_INET6", 443, ipv6, ipv6, Socket::Constants::AF_INET6, 3, 0])
      print address_info, "\n\n"
    end
  end

  describe "DNS resolution performance" do
    def resolve_address_with_scheduler(hostname, port, num_times)
      Thread.new do
        scheduler = AsyncScheduler::Scheduler.new
        Fiber.set_scheduler scheduler
        t = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        num_times.times do
          Fiber.schedule do
            Socket.getaddrinfo("www.google.com", 443)
          end
        end

        scheduler.close
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
      end.value
    end

    def resolve_address_sequentially(hostname, port, num_times)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      num_times.times do
        Socket.getaddrinfo("www.google.com", 443)
      end
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
    end


    def resolve_address_with_multithreads(hostname, port, num_times)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      threads = []
      num_times.times do
        threads << Thread.new do
          Socket.getaddrinfo("www.google.com", 443)
        end
      end
      # NOTE: I could not find how to wait for multiple threads to join in a Promise.all equivalent manner in Ruby.
      threads.each(&:join)
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
          puts "Revolve sequentially in a single thread: #{resolve_address_sequentially(hostname, 443, num_times)}"
          puts "Resolve with multithreads: #{resolve_address_with_multithreads(hostname, 443, num_times)}"
          puts
        end
      end
    end
  end
end
