# frozen_string_literal: true

Rails.application.configure do
  config.x.redmine.base_url = ENV.fetch("REDMINE_URL", nil)
  config.x.redmine.api_key = ENV.fetch("REDMINE_API_KEY", nil)
  config.x.redmine.project_identifier = ENV.fetch("REDMINE_PROJECT_IDENTIFIER", nil)
  config.x.redmine.embed = true
  config.x.redmine.issue_limit = ENV.fetch("REDMINE_PAGE_SIZE", 100).to_i
end
