module CrossThreadUsageDetector
  class OriginalThreadAlreadySetError < StandardError; end
  class CrossThreadUsageError < StandardError; end

  def set_belonging_thread(original_thread_object_id)
    if defined? @belonging_thread_object_id
      raise OriginalThreadAlreadySetError.new("@belonging_thread_object_id is already set with #{@belonging_thread_object_id}, but it is attempted to set again with #{original_thread_object_id}.")
    end

    @belonging_thread_object_id = original_thread_object_id
  end

  def validate_used_in_original_thread!(another_thread_object_id)
    return if @belonging_thread_object_id == another_thread_object_id

    raise CrossThreadUsageError.new("Cross-thread usage detected. FiberScheduler was originally registered to a thread (#{@belonging_thread_object_id}), but it is attempted to be used in another thread (#{another_thread_object_id}).")
  end
end
