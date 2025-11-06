# frozen_string_literal: true

module Gitlab
  class IssueAssigneeResolver
    USERNAME_PATTERN = /\A[\w\.-]+\z/

    def initialize(client:, mapping: {})
      @client = client
      @mapping = build_mapping(mapping)
      @username_cache = {}
      @search_cache = {}
    end

    def assignee_ids_for(issue)
      identifier = identifier_for(issue.assignee_name)
      return [] if identifier.blank?

      return [identifier.to_i] if numeric_identifier?(identifier)

      id = if username?(identifier)
        fetch_user_id(identifier)
      else
        search_user_id(identifier)
      end

      id ? [id] : []
    end

    private

    def build_mapping(mapping)
      mapping.to_h.each_with_object({}) do |(raw_name, user), memo|
        key = raw_name.to_s.strip.downcase
        next if key.blank? || user.blank?

        identifier = normalize_identifier(user)
        memo[key] = identifier

        inferred = convert_to_full_name(raw_name)
        memo[inferred.downcase] = identifier if inferred.present?
      end
    end

    def identifier_for(name)
      return if name.blank?

      trimmed = name.to_s.strip
      mapping_key = trimmed.downcase
      @mapping[mapping_key] || convert_to_full_name(trimmed) || trimmed
    end

    def fetch_user_id(username)
      return @username_cache[username] if @username_cache.key?(username)

      user = @client.find_user(username: username)
      @username_cache[username] = user&.fetch('id', nil)
    rescue StandardError => e
      Rails.logger.warn("[GitLab] Assignee lookup failed for #{username}: #{e.message}")
      @username_cache[username] = nil
    end

    def normalize_identifier(value)
      identifier = value.to_s.strip
      identifier = identifier.delete_prefix('@')
      identifier
    end

    def numeric_identifier?(identifier)
      identifier.match?(/\A\d+\z/)
    end

    def username?(identifier)
      identifier.match?(USERNAME_PATTERN)
    end

    # Redmine exposes assignee names as "Last, First"; convert to "First Last" for GitLab search.
    def convert_to_full_name(raw_name)
      parts = raw_name.to_s.split(',').map(&:strip)
      return nil unless parts.size == 2

      first = parts[1]
      last = parts[0]
      full_name = [first, last].join(' ').strip
      full_name.presence
    end

    def search_user_id(full_name)
      return @search_cache[full_name] if @search_cache.key?(full_name)

      results = @client.search_users(search: full_name)
      match = results.find do |user|
        user_name = user['name'].to_s.downcase
        user_name == full_name.downcase
      end || results.first

      @search_cache[full_name] = match&.fetch('id', nil)
    rescue StandardError => e
      Rails.logger.warn("[GitLab] User search failed for #{full_name}: #{e.message}")
      @search_cache[full_name] = nil
    end
  end
end
