# frozen_string_literal: true

module IssueTransfer
  class RedminePayloadBuilder
    def initialize(issue:)
      @issue = issue
    end

    def call
      {
        'id' => integer_or_string(issue.external_id),
        'subject' => issue.title,
        'description' => issue.description,
        'status' => nested_hash(issue.status, 'name'),
        'tracker' => nested_hash(issue.tracker, 'name'),
        'priority' => nested_hash(issue.priority, 'name'),
        'project' => project_hash,
        'assigned_to' => nested_hash(issue.assignee_name, 'name'),
        'author' => nested_hash(issue.author_name, 'name'),
        'start_date' => date_string(issue.created_at),
        'updated_on' => iso(issue.updated_on),
        'created_on' => iso(issue.created_at),
        'closed_on' => iso(issue.closed_on),
        'done_ratio' => nil,
        'custom_fields' => custom_fields,
        'fixed_version' => fixed_version_hash
      }.compact
    end

    private

    attr_reader :issue

    def nested_hash(value, key)
      return nil if value.blank?

      { key => value }
    end

    def fixed_version_hash
      return unless issue.fixed_version_id.present? || issue.fixed_version_name.present?

      {
        'id' => issue.fixed_version_id,
        'name' => issue.fixed_version_name
      }.compact
    end

    def project_hash
      return if issue.project_identifier.blank?

      {
        'identifier' => issue.project_identifier,
        'name' => issue.project_identifier
      }
    end

    def custom_fields
      fields = []
      append_custom_field(fields, 'Releasenotes', issue.release_notes)
      append_custom_field(fields, 'Releasenotes veröffentlichen', issue.release_notes_publish)
      append_custom_field(fields, 'Wiedervorlage', issue.follow_up_on)
      append_custom_field(fields, 'Complexity', issue.complexity)
      append_custom_field(fields, 'Kategorie', issue.category_name)
      append_custom_field(fields, 'Gültig für', issue.valid_for)
      fields
    end

    def append_custom_field(collection, name, value)
      return if value.nil?

      formatted = case value
      when TrueClass then '1'
      when FalseClass then '0'
      else
        value
      end

      collection << {
        'name' => name,
        'value' => formatted
      }
    end

    def integer_or_string(value)
      return if value.blank?

      Integer(value, exception: false) || value
    end

    def date_string(value)
      return unless value

      value.to_date.to_s
    end

    def iso(value)
      return unless value

      value.iso8601
    end
  end
end
