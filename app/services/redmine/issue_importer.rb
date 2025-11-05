# frozen_string_literal: true

module Redmine
  class IssueImporter
    attr_reader :processed_count

    def initialize(client:, project_identifier:, embed: true, logger: Rails.logger, limit: nil, sort: nil, updated_since: nil)
      @client = client
      @project_identifier = project_identifier
      @embed = embed
      @logger = logger
      @limit = limit&.to_i if limit
      @sort = sort
      @updated_since = parse_time(updated_since)
      @processed_count = 0
    end

    def call
      offset = 0
      total = nil
      remaining = @limit
      loop do
        request_limit = remaining ? [remaining, @client.page_size].min : nil
        batch = @client.issues(
          project: @project_identifier,
          offset: offset,
          updated_since: @updated_since,
          sort: @sort,
          limit: request_limit
        )
        issues = batch[:issues]
        total ||= batch[:total_count]
        break if issues.empty?

        issues.each { |attrs| upsert_issue(attrs) }
        offset += issues.size
        remaining -= issues.size if remaining
        break if remaining&.<= 0
        break if offset >= total
      end
    end

    private

    def upsert_issue(attrs)
      issue_id = attrs['id'].to_s
      issue = Issue.find_or_initialize_by(external_id: issue_id)
      issue.project_identifier = attrs.dig('project', 'identifier') || @project_identifier
      issue.tracker = attrs.dig('tracker', 'name')
      issue.status = attrs.dig('status', 'name')
      issue.priority = attrs.dig('priority', 'name')
      issue.title = attrs['subject']
      issue.description = attrs['description']
      issue.assignee_name = attrs.dig('assigned_to', 'name')
      issue.author_name = attrs.dig('author', 'name')
      issue.closed_on = parse_time(attrs['closed_on'])
      issue.updated_on = parse_time(attrs['updated_on'])
      issue.raw_payload = attrs
      issue.save!

      @processed_count += 1

      return unless @embed && issue.description.present?

      Embedding.refresh_for!(
        source: issue,
        content: issue.embed_payload,
        metadata: {
          source: 'redmine_issue',
          external_url: issue.external_url,
          project: issue.project_identifier
        }
      )
    rescue StandardError => e
      @logger.error("[Redmine] Issue import failed for ##{issue_id}: #{e.message}")
    end

    def parse_time(value)
      return if value.blank?
      return value if value.is_a?(Time)

      Time.zone.parse(value.to_s)
    rescue StandardError
      nil
    end
  end
end
