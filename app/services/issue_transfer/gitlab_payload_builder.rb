# frozen_string_literal: true

module IssueTransfer
  class GitlabPayloadBuilder
    STATE_CLOSED_VALUES = %w[geschlossen closed erledigt done].freeze

    def initialize(issue:, label_mapper: nil, assignee_resolver: nil, project_path: nil)
      @issue = issue
      @label_mapper = label_mapper
      @assignee_resolver = assignee_resolver
      @project_path = resolve_project_path(project_path)
    end

    def call
      {
          iid: issue.gitlab_issue_iid,
          project_path: project_path,
          title: issue.title,
          description: build_description,
          labels: labels,
          assignee_ids: assignee_ids,
          assignees: assignee_structs,
          web_url: issue.gitlab_issue_web_url,
          state: state,
          checksum: issue.gitlab_sync_checksum,
          last_synced_at: iso(issue.gitlab_last_synced_at),
          updated_at: iso(issue.updated_at),
          created_at: iso(issue.created_at),
          external_references: external_references,
          payload: build_payload
      }.compact
    end

    private

    attr_reader :issue, :label_mapper, :assignee_resolver, :project_path

    def resolve_project_path(path)
      explicit = path.presence
      return explicit if explicit

      issue_path = issue.gitlab_issue_project_path.presence
      return issue_path if issue_path

      config_path = Rails.application.config.x.gitlab.project_path rescue nil
      config_path.presence
    end

    def labels
      @labels ||= begin
        if label_mapper
          label_mapper.labels_for(issue)
        else
          Array(issue.gitlab_labels)
        end
      end
    end

    def assignee_ids
      @assignee_ids ||= begin
        if assignee_resolver
          if Gitlab::LabelMapper.planning_assignee?(issue.assignee_name)
            []
          else
            ids = Array(assignee_resolver.assignee_ids_for(issue)).compact
            ids = issue.gitlab_assignee_ids if ids.blank?
            ids
          end
        else
          issue.gitlab_assignee_ids
        end
      end
    end

    def assignee_structs
      assignee_ids.map { |id| { 'id' => id } }
    end

    def build_description
      sections = []

      ticket_reference = if issue.external_url.present?
        "**Redmine Ticket:** [##{issue.external_id}](#{issue.external_url})"
      else
        "**Redmine Ticket:** ##{issue.external_id}"
      end
      sections << ticket_reference

      metadata_lines = []
      metadata_lines << "**Tracker:** #{issue.tracker}" if issue.tracker.present?
      metadata_lines << "**Status:** #{issue.status}" if issue.status.present?
      metadata_lines << "**Priority:** #{issue.priority}" if issue.priority.present?
      metadata_lines << "**Assignee:** #{issue.assignee_name}" if issue.assignee_name.present?
      metadata_lines << "**Author:** #{issue.author_name}" if issue.author_name.present?
      metadata = metadata_lines.join("\n")
      sections << metadata if metadata.present?

      description = issue.description.to_s.strip
      if description.present?
        formatted_description = description.gsub("\r\n", "\n").strip
        sections << "### Description\n\n#{formatted_description}"
      end

      sections.compact.join("\n\n")
    end

    def build_payload
      payload = {
          title: issue.title,
          description: build_description
      }

      joined = labels.join(',') if labels.any?
        payload[:labels] = joined if joined.present?

        payload[:assignee_ids] = assignee_ids unless assignee_ids.nil?
      payload
    end

    def state
      value = issue.status.to_s.downcase
      STATE_CLOSED_VALUES.any? { |closed| value.include?(closed) } ? 'closed' : 'opened'
    end

    def external_references
      return unless issue.external_id.present?

      {
          redmine: {
            external_id: issue.external_id,
            url: issue.external_url
        }.compact
      }
    end

    def iso(value)
      value&.iso8601
    end
  end
end
