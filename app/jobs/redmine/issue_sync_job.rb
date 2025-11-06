# frozen_string_literal: true

module Redmine
  class IssueSyncJob < ApplicationJob
    queue_as :default

    def perform(limit: nil, sort: 'updated_on:desc', embed: false)
      redmine_config = Rails.application.config.x.redmine
      schedule = SyncSchedule.fetch(task_name: 'jobs:redmine_issue_sync', scope: redmine_config.query_id)

      raw_checkpoint = schedule.checkpoint || default_checkpoint
      minimum_since = resolve_minimum_since(redmine_config)
      checkpoint = clamp_checkpoint(raw_checkpoint, minimum_since)
      logger.info("[Redmine::IssueSyncJob] Starting sync since #{checkpoint || 'beginning'} (minimum #{minimum_since})")

      schedule.mark_started!

      runner = IssueTransfer::SyncRunner.new
      effective_limit = determine_limit(limit, schedule, redmine_config)

      summary = runner.call(updated_since: checkpoint, limit: effective_limit, sort: sort, embed: embed)

      schedule.mark_succeeded!

      logger.info("[Redmine::IssueSyncJob] Completed. Imported=#{summary.processed_count} GitLab=#{summary.gitlab_results.count} Limit=#{effective_limit || 'unbounded'}")
      summary
    rescue StandardError => e
      schedule.record_error!(e.message) if defined?(schedule) && schedule.present?
      logger.error("[Redmine::IssueSyncJob] Failed: #{e.message}")
      raise
    end

    private

    def default_checkpoint
      3.minutes.ago
    end

    def determine_limit(requested_limit, schedule, redmine_config)
      return sanitize_limit(requested_limit) if requested_limit.present?

      if schedule.last_success_at.blank?
        return sanitize_limit(redmine_config.initial_sync_limit)
      end

      sanitize_limit(redmine_config.recurring_sync_limit)
    end

    def sanitize_limit(value)
      return nil if value.blank?

      limit = value.to_i
      limit > 0 ? limit : nil
    end

    def resolve_minimum_since(redmine_config)
      value = redmine_config.min_updated_since
      return parse_time_string(value) if value.present?

      Time.zone.local(2025, 1, 1)
    rescue StandardError
      Time.zone.local(2025, 1, 1)
    end

    def clamp_checkpoint(checkpoint, minimum_since)
      return minimum_since if checkpoint.blank?

      checkpoint < minimum_since ? minimum_since : checkpoint
    end

    def parse_time_string(value)
      return value if value.is_a?(Time)

      Time.zone.parse(value.to_s)
    end
  end
end
