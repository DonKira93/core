# frozen_string_literal: true

module Redmine
  class IssueImporter
    attr_reader :processed_count, :processed_ids

    def initialize(client:, query_id:, embed: true, logger: Rails.logger, limit: nil, sort: nil, updated_since: nil)
      raise ArgumentError, "Redmine query ID is required" if query_id.blank?

      @client = client
      @query_id = query_id
      @embed = embed
      @logger = logger
      @limit = limit&.to_i if limit
      @sort = sort
      @updated_since = parse_time(updated_since)
      @processed_count = 0
      @processed_ids = []
    end

    def call
      offset = 0
      total = nil
      remaining = @limit
      loop do
        request_limit = remaining ? [remaining, @client.page_size].min : nil
        batch = @client.issues(
          query_id: @query_id,
          offset: offset,
          updated_since: @updated_since,
          sort: @sort,
          limit: request_limit
        )
        issues = batch[:issues]
        total ||= batch[:total_count]

        if issues.empty?
          if offset.zero?
            message = "[Redmine] Saved query #{@query_id} returned no issues. Double-check the filters or visibility."
            @logger.warn(message)
            Kernel.warn(message)
          end
          break
        end

        issues.each { |attrs| upsert_issue(attrs) }
        offset += issues.size
        remaining -= issues.size if remaining
        break if remaining&.<= 0
        break if offset >= total
      end
    end

    private

    def upsert_issue(attrs)
      puts "Processing issue ##{attrs['id']}: #{attrs['subject']}"
      issue_id = attrs['id'].to_s
      issue = Issue.find_or_initialize_by(external_id: issue_id)

      project_data = attrs['project'] || {}
      project_key = project_data['identifier'].presence || project_data['name'].presence || "query-#{@query_id}"
      issue.project_identifier = project_key
      issue.tracker = attrs.dig('tracker', 'name')
      issue.status = attrs.dig('status', 'name')
      issue.priority = attrs.dig('priority', 'name')
      issue.title = attrs['subject']
      issue.description = attrs['description']
      issue.assignee_name = attrs.dig('assigned_to', 'name')
      issue.author_name = attrs.dig('author', 'name')
      issue.closed_on = parse_time(attrs['closed_on'])
      issue.updated_on = parse_time(attrs['updated_on'])
      assign_fixed_version(issue, attrs['fixed_version'])
      assign_custom_fields(issue, attrs['custom_fields'])
      puts "#{issue.errors.full_messages.join(', ')}" unless issue.errors.empty?
      issue.save!

      @processed_count += 1
      @processed_ids << issue.external_id
      @processed_ids.uniq!

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
      error_details = issue.errors.full_messages.presence&.join(', ')
      message = "[Redmine] Issue import failed for ##{issue_id}: #{e.message}"
      message = "#{message} (#{error_details})" if error_details
      @logger.error(message)
      Kernel.warn(message)
    end

    def parse_time(value)
      return if value.blank?
      return value if value.is_a?(Time)

      Time.zone.parse(value.to_s)
    rescue StandardError
      nil
    end

    def assign_fixed_version(issue, version)
      return unless version.is_a?(Hash)

      issue.fixed_version_id = version['id'] if version.key?('id')
      issue.fixed_version_name = version['name'] if version.key?('name')
    end

    def assign_custom_fields(issue, fields)
      custom_fields = Array(fields).each_with_object({}) do |field, memo|
        next unless field.is_a?(Hash)

        name = field['name']
        value = field['value']
        value = value.join(', ') if value.is_a?(Array)
        memo[name] = value
      end

      issue.release_notes = custom_fields['Releasenotes']
      issue.release_notes_publish = custom_fields['Releasenotes veröffentlichen']
      issue.follow_up_on = custom_fields['Wiedervorlage']
      issue.complexity = custom_fields['Complexity']
      issue.category_name = custom_fields['Kategorie']
      issue.valid_for = custom_fields['Gültig für']
    end
  end
end
