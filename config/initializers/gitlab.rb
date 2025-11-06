# frozen_string_literal: true

require 'json'

Rails.application.configure do
  config.x.gitlab.base_url = ENV.fetch("GITLAB_URL", nil)
  config.x.gitlab.private_token = ENV.fetch("GITLAB_TOKEN", nil)
  config.x.gitlab.project_path = ENV.fetch("GITLAB_PROJECT_PATH", nil)
  config.x.gitlab.embed = true
  config.x.gitlab.per_page = ENV.fetch("GITLAB_PAGE_SIZE", 100).to_i
end
