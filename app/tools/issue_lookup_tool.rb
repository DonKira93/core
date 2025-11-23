# frozen_string_literal: true

require "json"

class IssueLookupTool < ApplicationTool
  description "Search locally cached GitLab issues by text or Redmine ID and return Redmine IDs"

  annotations(
    title: "Find Issues",
    read_only_hint: true,
    open_world_hint: false
  )

  DEFAULT_LIMIT = 20

  arguments do
    required(:query).filled(:string).description("Substring to match against issue title/description or a Redmine ID like #12345")
    optional(:limit).filled(:integer).description("Maximum number of matches to return (default 20)")
  end

  def call(query:, limit: nil)
    sanitized_limit = sanitize_limit(limit)
    matches = search_scope(query).order(updated_on: :desc, id: :desc).limit(sanitized_limit)

    payload = matches.map do |issue|
      {
        redmine_id: issue.external_id,
        title: issue.title,
        updated_on: issue.updated_on,
        gitlab_issue_iid: issue.gitlab_issue_iid
      }.compact
    end

    JSON.pretty_generate(results: payload, count: payload.size)
  rescue StandardError => e
    JSON.pretty_generate(error: e.message)
  end

  private

  def search_scope(query)
    redmine_id = extract_redmine_id(query)
    scope = Gitlab::Issue.all
    return scope.where(external_id: redmine_id) if redmine_id

    scope.where("title ILIKE :q OR description ILIKE :q OR external_id ILIKE :q", q: pattern_for(query))
  end

  def extract_redmine_id(query)
    candidate = query.to_s.strip
    candidate = candidate.delete_prefix("#")
    return candidate if candidate.match?(/\A\d+\z/)
  end

  def pattern_for(query)
    "%#{query}%"
  end

  def sanitize_limit(limit)
    size = limit.to_i if limit
    size = DEFAULT_LIMIT unless size&.positive?
    size
  end
end
