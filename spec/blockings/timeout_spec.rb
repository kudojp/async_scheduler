# frozen_string_literal: true
require 'timeout'

RSpec.describe AsyncScheduler do
  class CustomTimeoutError < StandardError; end
  describe "Timeout.timeout() called asynchronously" do
    context "when Timeout.timeout is called with duration which is longer than the block execution time" do
      it "returns the return value of the block" do
        thread = Thread.new do
          Fiber.set_scheduler AsyncScheduler::Scheduler.new
          Fiber.schedule do
            t = Time.now
            timeout_error_message = "timeout!"
            expect(
              Timeout.timeout(1, CustomTimeoutError, timeout_error_message) do
                sleep(0.5)
                break 12
              end
            ).to eq(12)
          end
        end
        thread.join
      end
    end

    context "when Timeout.timeout is called with duration which is shorter than the block execution time" do
      ### This test case is skipped for now because this spec should last forever.
      ### Uncomment and confirm it if related changes are made.
      #
      # context "when block execution time is eternal" do
      #   it "raises an error as specified with arguments" do
      #     thread = Thread.new do
      #       Fiber.set_scheduler AsyncScheduler::Scheduler.new
      #       Fiber.schedule do
      #         t = Time.now
      #         timeout_error_message = "timeout!"
      #         expect{
      #           Timeout.timeout(nil, CustomTimeoutError, timeout_error_message) do
      #             sleep()
      #           end
      #         }.to raise_error(CustomTimeoutError, timeout_error_message)
      #       end
      #     end
      #     thread.join
      #   end
      # end

      context "when block execution time is specified" do
        it "raises an error as specified with arguments" do
          thread = Thread.new do
            Fiber.set_scheduler AsyncScheduler::Scheduler.new
            Fiber.schedule do
              t = Time.now
              timeout_error_message = "timeout!"
              expect{
                Timeout.timeout(0.5, CustomTimeoutError, timeout_error_message) do
                  sleep(1)
                end
              }.to raise_error(CustomTimeoutError, timeout_error_message)
            end
          end
          thread.join
        end
      end
    end

    context "when Timeout.timeout is called with nil as the duration" do
      it "returns the return value of the block" do
        thread = Thread.new do
          Fiber.set_scheduler AsyncScheduler::Scheduler.new
          Fiber.schedule do
            t = Time.now
            timeout_error_message = "timeout!"
            expect(
              Timeout.timeout(nil, CustomTimeoutError, timeout_error_message) do
                sleep(0.5)
                break 12
              end
            ).to eq(12)
          end
        end
        thread.join
      end
    end
  end
end
