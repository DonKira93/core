# frozen_string_literal: true

module IssueTransfer
  class SyncRunner
    SyncResult = Struct.new(:issue, :status, :result, keyword_init: true)
    RunSummary = Struct.new(:processed_count, :processed_ids, :gitlab_results, keyword_init: true)

    def initialize(
      redmine_config: Rails.application.config.x.redmine,
      gitlab_config: Rails.application.config.x.gitlab,
      logger: Rails.logger
    )
      @redmine_config = redmine_config
      @gitlab_config = gitlab_config
      @logger = logger
    end

    def call(updated_since:, limit: nil, sort: nil, embed: nil)
      ensure_redmine_config!
      importer = build_importer(updated_since: updated_since, limit: limit, sort: sort, embed: embed)
      importer.call

      issues = fetch_issues(importer.processed_ids)
      gitlab_results = sync_gitlab(issues)

      RunSummary.new(
        processed_count: importer.processed_count,
        processed_ids: importer.processed_ids,
        gitlab_results: gitlab_results
      )
    end

    private

    attr_reader :redmine_config, :gitlab_config, :logger

    def ensure_redmine_config!
      required = {
        base_url: redmine_config.base_url,
        api_key: redmine_config.api_key,
        query_id: redmine_config.query_id
      }

      missing = required.select { |_, value| value.blank? }
      return if missing.empty?

      raise ArgumentError, "Missing Redmine configuration keys: #{missing.keys.join(', ')}"
    end

    def build_importer(updated_since:, limit:, sort:, embed:)
      client = redmine_client
      Redmine::IssueImporter.new(
        client: client,
        query_id: redmine_config.query_id,
        limit: limit,
        sort: sort.presence || 'updated_on:desc',
        embed: embed.nil? ? redmine_config.embed : embed,
        updated_since: updated_since,
        logger: logger
      )
    end

    def redmine_client
      @redmine_client ||= Redmine::Client.new(
        base_url: redmine_config.base_url,
        api_key: redmine_config.api_key,
        page_size: redmine_config.issue_limit
      )
    end

    def fetch_issues(external_ids)
      return Issue.none if external_ids.blank?

      Issue.where(external_id: external_ids).order(updated_on: :desc)
    end

    def sync_gitlab(issues)
      return [] if issues.blank?
      return [] unless gitlab_enabled?

      publisher = gitlab_publisher
      issues.map do |issue|
        begin
          result = publisher.publish(issue)
          SyncResult.new(issue: issue, status: result.status, result: result)
        rescue StandardError => e
          logger.error("[IssueTransfer] GitLab publish failed for Redmine ##{issue.external_id}: #{e.message}")
          SyncResult.new(issue: issue, status: :error, result: e)
        end
      end
    end

    def gitlab_enabled?
      required = {
        base_url: gitlab_config.base_url,
        private_token: gitlab_config.private_token,
        project_path: gitlab_project_path
      }

      missing = required.select { |_, value| value.blank? }
      if missing.any?
        logger.warn("[IssueTransfer] Skipping GitLab sync due to missing config keys: #{missing.keys.join(', ')}")
        return false
      end

      true
    end

    def gitlab_publisher
      Gitlab::IssuePublisher.new(
        client: gitlab_client,
        project_path: gitlab_project_path,
        label_mapper: gitlab_label_mapper,
        assignee_resolver: gitlab_assignee_resolver
      )
    end

    def gitlab_client
      @gitlab_client ||= Gitlab::Client.new(
        base_url: gitlab_config.base_url,
        private_token: gitlab_config.private_token,
        per_page: gitlab_config.per_page
      )
    end

    def gitlab_project_path
      gitlab_config.project_path
    end

    def gitlab_label_mapper
      available_labels = if defined?(GitlabLabel)
        GitlabLabel.names_for(gitlab_project_path)
      end

      Gitlab::LabelMapper.new(available_labels: available_labels)
    end

    def gitlab_assignee_resolver
      Gitlab::IssueAssigneeResolver.new(
        client: gitlab_client,
        mapping: gitlab_config.assignee_map || {}
      )
    end
  end
end
