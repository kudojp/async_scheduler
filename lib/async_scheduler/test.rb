# frozen_string_literal: true

require_relative "async_resolv/version"
require "resolv"

module Resolv
  def self.getaddresses_fiber(hostname)
      Fiber.new do
        Resolv.getaddresses(hostname)
      end
    end
  end

  Resolv::DNS::Requester
    def request_nonblock(sender, tout)
      raise
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      timelimit = start + tout
      begin
        sender.send
      rescue Errno::EHOSTUNREACH, # multi-homed IPv6 may generate this
              Errno::ENETUNREACH
        raise ResolvTimeout
      end
      while true
        before_select = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        timeout = timelimit - before_select
        if timeout <= 0
          raise ResolvTimeout
        end

        # Use the self pipe trick
        self_reader, self_writer = IO.pipe
        @socks << self_reader
        self_writer.write 0

        select_result = IO.select(@socks, nil, nil, timeout)

        @socks.delete self_reader
        select_result[0].delete self_reader

        if select_result[0].empty?
          Fiber.yield :try_again
          next
        end

        begin
          reply, from = recv_reply(select_result[0])
        rescue Errno::ECONNREFUSED, # GNU/Linux, FreeBSD
                Errno::ECONNRESET # Windows
          # No name server running on the server?
          # Don't wait anymore.
          raise ResolvTimeout
        end
        begin
          msg = Message.decode(reply)
        rescue DecodeError
          next # broken DNS message ignored
        end

        if sender == sender_for(from, msg)
          break
        else
          # unexpected DNS message ignored
        end
      end
      return msg, sender.data
    end
    # private :request
  end
end
