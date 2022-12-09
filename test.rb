require "./lib/async_scheduler"

s = AsyncScheduler::Scheduler.new
thread_ids = {}
Fiber.set_scheduler s
thread_ids = { parent_thread_id: Thread.current.object_id }
scheduler_ids = { parent_scheduler_id: Fiber.scheduler.object_id }
begin
  Fiber.schedule do
    child_thread = Thread.new do
      thread_ids[:child_thread_id] = Thread.current.object_id
      scheduler_ids[:child_scheduler_id] = Fiber.scheduler.object_id ### somehow 8 = nil here
    end

    child_thread.join
  end
rescue FiberError
  puts "\n### thread_ids ####"
  puts thread_ids
  puts "\n### scheduler_ids ####"
  puts scheduler_ids
  puts "\n### All points where tasks are resumed ####"
  puts s.resumers
end
