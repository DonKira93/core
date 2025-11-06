# frozen_string_literal: true

class SyncSchedule < ApplicationRecord
  validates :task_name, presence: true

  scope :for_task, ->(task_name) { where(task_name: task_name) }

  def self.fetch(task_name:, scope: nil)
    find_or_create_by!(task_name: task_name, scope: scope)
  end

  def mark_started!
    touch(:last_run_at)
  end

  def mark_succeeded!
    update!(last_success_at: Time.current, last_error: nil)
  end

  def record_error!(message)
    value = Array(message).compact.join(', ').presence
    update!(last_error: value)
  end

  def checkpoint
    last_success_at || last_run_at
  end
end
