# frozen_string_literal: true

require 'json'

Rails.application.configure do
  config.x.gitlab.base_url = ENV.fetch("GITLAB_URL", nil)
  config.x.gitlab.private_token = ENV.fetch("GITLAB_TOKEN", nil)
  config.x.gitlab.project_path = ENV.fetch("GITLAB_PROJECT_PATH", nil)
  config.x.gitlab.embed = true
  config.x.gitlab.per_page = ENV.fetch("GITLAB_PAGE_SIZE", 100).to_i

  raw_map = ENV.fetch("GITLAB_ASSIGNEE_MAP", nil)
  config.x.gitlab.assignee_map = begin
    if raw_map.present?
      stripped = raw_map.strip

      mapping = if stripped.start_with?('{')
        JSON.parse(stripped)
      else
        {}
      end

      if mapping.blank?
        stripped.split(';').each_with_object({}) do |entry, memo|
          name, username = entry.split('=', 2)
          next if name.blank? || username.blank?

          memo[name.strip] = username.strip
        end
      else
        mapping
      end
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end
end
