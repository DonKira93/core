# frozen_string_literal: true

require 'digest'

module Gitlab
  class IssuePublisher
    class Result
      attr_reader :status, :response, :payload, :checksum

      def initialize(status:, response:, payload:, checksum:)
        @status = status
        @response = response
        @payload = payload
        @checksum = checksum
      end

      def created?
        status == :created
      end

      def updated?
        status == :updated
      end

      def skipped?
        status == :skipped
      end
    end

    SKIPPED_STATUSES = %w[terminiert geschlossen].freeze

    def initialize(client:, project_path:)
      @client = client
      @project_path = project_path
    end

    def publish(issue)
      check_issue!(issue)
      if skip_status?(issue)
        Rails.logger.info("[GitLab] Skipping publish for Redmine ##{issue.external_id} (status=#{issue.status})")
        return Result.new(status: :skipped, response: nil, payload: {}, checksum: nil)
      end
      ensure_remote_reference(issue)

      snapshot = build_snapshot(issue)
      payload = snapshot.fetch(:payload).dup
      payload.delete(:assignee_ids)
      labels = Array(snapshot[:labels])
      assignee_ids = nil
      checksum = checksum_for(payload, labels, assignee_ids)

      if issue.gitlab_issue_iid.present?
        return handle_existing_issue(issue, labels, assignee_ids, payload, checksum)
      end

      response = @client.create_issue(project: @project_path, params: payload)
      persist_sync_state(issue, labels, assignee_ids, checksum, response: response)

      Result.new(status: :created, response: response, payload: payload, checksum: checksum)
    end

    def payload_for(issue)
      check_issue!(issue)

      build_snapshot(issue).fetch(:payload)
    end

    def labels_for(issue)
      check_issue!(issue)
      Array(build_snapshot(issue)[:labels])
    end

    private

    def check_issue!(issue)
      raise ArgumentError, 'Issue is required' unless issue
      raise ArgumentError, 'Issue must be persisted' unless issue.persisted?
    end

    def build_snapshot(issue)
      IssueTransfer::GitlabPayloadBuilder.new(
        issue: issue,
        project_path: @project_path
      ).call
    end

    def handle_existing_issue(issue, labels, assignee_ids, payload, checksum)
      if issue.gitlab_sync_checksum.present? && issue.gitlab_sync_checksum == checksum
        persist_sync_state(issue, labels, assignee_ids, checksum)
        return Result.new(status: :skipped, response: nil, payload: payload, checksum: checksum)
      end

      project_path = issue.gitlab_issue_project_path.presence || @project_path
      response = @client.update_issue(
        project: project_path,
        issue_iid: issue.gitlab_issue_iid,
        params: payload
      )

      persist_sync_state(issue, labels, assignee_ids, checksum, response: response)
      Result.new(status: :updated, response: response, payload: payload, checksum: checksum)
    end

    def persist_sync_state(issue, labels, assignee_ids, checksum, response: nil)
      project_path = issue.gitlab_issue_project_path.presence || @project_path

      issue.transaction do
        issue.gitlab_labels = labels if labels
        issue.gitlab_assignee_ids = assignee_ids unless assignee_ids.nil?

        issue.assign_attributes(
          gitlab_sync_checksum: checksum,
          gitlab_last_synced_at: Time.current,
          gitlab_issue_project_path: project_path.presence
        )

        if response
          issue.assign_attributes(
            gitlab_issue_iid: response['iid'] || response['id'] || issue.gitlab_issue_iid,
            gitlab_issue_web_url: response['web_url'] || response['html_url'] || issue.gitlab_issue_web_url
          )
        end

        issue.save!
      end
    rescue StandardError => e
      Rails.logger.warn("[GitLab] Failed to persist GitLab sync state for issue ##{issue.external_id}: #{e.message}")
    end

    def checksum_for(payload, labels, assignee_ids)
      parts = [
        payload[:title].to_s,
        payload[:description].to_s,
        Array(labels).map(&:to_s).sort.join(','),
        Array(assignee_ids).map(&:to_i).sort.join(',')
      ]

      Digest::SHA256.hexdigest(parts.join("\u0000"))
    end

    def ensure_remote_reference(issue)
      return if issue.gitlab_issue_iid.present?

      existing = find_existing_issue(issue)
      return unless existing

      iid = existing['iid'] || existing['id']
      return unless iid

      project_path = issue.gitlab_issue_project_path.presence || @project_path

      attributes = {
        gitlab_issue_iid: iid,
        gitlab_issue_project_path: project_path,
        gitlab_issue_web_url: existing['web_url'] || existing['html_url']
      }.compact

      issue.update!(attributes)
    rescue StandardError => e
      Rails.logger.warn("[GitLab] Failed to link existing GitLab issue for Redmine ##{issue.external_id}: #{e.message}")
    end

    def find_existing_issue(issue)
      search_term = "Redmine ##{issue.external_id}"
      candidates = Array(@client.search_issues(project: @project_path, search: search_term, scope: 'description', state: 'all'))

      candidates.find do |candidate|
        candidate_description = candidate['description'].to_s
        candidate_description.include?("Redmine ##{issue.external_id}")
      end
    rescue StandardError => e
      Rails.logger.warn("[GitLab] Search failed while looking for existing issue for Redmine ##{issue.external_id}: #{e.message}")
      nil
    end

    def skip_status?(issue)
      status = issue.status.to_s.strip.downcase
      SKIPPED_STATUSES.include?(status)
    end
  end
end
