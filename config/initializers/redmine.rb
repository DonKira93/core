# frozen_string_literal: true

Rails.application.configure do
  config.x.redmine.base_url = ENV.fetch("REDMINE_URL", nil)
  config.x.redmine.api_key = ENV.fetch("REDMINE_API_KEY", nil)
  config.x.redmine.query_id = ENV.fetch("REDMINE_QUERY_ID", nil)&.presence
  config.x.redmine.embed = true
  config.x.redmine.issue_limit = ENV.fetch("REDMINE_PAGE_SIZE", 100).to_i
  initial_sync_limit = ENV.fetch("REDMINE_INITIAL_SYNC_LIMIT", nil)
  config.x.redmine.initial_sync_limit = initial_sync_limit.present? ? initial_sync_limit.to_i : nil

  recurring_sync_limit = ENV.fetch("REDMINE_RECURRING_SYNC_LIMIT", nil)
  config.x.redmine.recurring_sync_limit = recurring_sync_limit.present? ? recurring_sync_limit.to_i : nil

  min_since_env = ENV.fetch("REDMINE_MIN_UPDATED_SINCE", nil)
  config.x.redmine.min_updated_since = min_since_env.presence || '2025-01-01'
end
