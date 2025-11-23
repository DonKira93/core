# frozen_string_literal: true

module DataRefresh
  class Coordinator
    DEFAULT_COMMIT_DIFF_LIMIT = 10

    def initialize(logger: Rails.logger)
      @logger = logger
    end

    def refresh_redmine_issues(since: nil, limit: nil, sort: nil, embed: nil)
      runner = IssueTransfer::SyncRunner.new(logger: logger)
      summary = runner.call(
        updated_since: parse_time(since),
        limit: sanitize_limit(limit),
        sort: sort,
        embed: boolean_override(redmine_config.embed, embed)
      )

      {
        processed_count: summary.processed_count,
        processed_ids: summary.processed_ids,
        gitlab_results: format_gitlab_results(summary.gitlab_results)
      }
    end

    def refresh_redmine_wiki(project_identifier: nil, embed: nil)
      project_identifier = project_identifier.presence || redmine_config.wiki_project
      raise ArgumentError, "Redmine wiki project is required" if project_identifier.blank?

      importer = Redmine::WikiImporter.new(
        client: redmine_client,
        project_identifier: project_identifier,
        embed: boolean_override(redmine_config.embed, embed),
        logger: logger
      )

      importer.call

      {
        processed_count: importer.processed_count,
        project_identifier: project_identifier
      }
    end

    def refresh_gitlab_commits(since: nil, limit: nil, embed: nil)
      importer = Gitlab::ChangelogImporter.new(
        client: gitlab_client,
        project_path: require_gitlab_project_path!,
        embed: boolean_override(gitlab_config.embed, embed),
        logger: logger,
        since: parse_time(since),
        limit: sanitize_limit(limit)
      )

      importer.call

      {
        processed_count: importer.processed_count,
        project_path: gitlab_config.project_path
      }
    end

    def refresh_gitlab_commit_diffs(shas: [], limit: nil, embed: nil)
      project_path = require_gitlab_project_path!
      embed = boolean_override(gitlab_config.embed, embed)

      target_shas = Array(shas).map(&:to_s).reject(&:blank?)
      if target_shas.empty?
        effective_limit = sanitize_limit(limit) || DEFAULT_COMMIT_DIFF_LIMIT
        target_shas = Gitlab::Commit.order(committed_at: :desc, created_at: :desc)
                                    .limit(effective_limit)
                                    .pluck(:sha)
      end

      raise ArgumentError, "No GitLab commit SHAs available to refresh" if target_shas.blank?

      importer = Gitlab::ChangelogImporter.new(
        client: gitlab_client,
        project_path: project_path,
        embed: embed,
        logger: logger
      )

      processed = []
      errors = []

      target_shas.each do |sha|
        commit = Gitlab::Commit.find_by(sha: sha)
        unless commit
          errors << { sha: sha, error: "Commit not found locally" }
          next
        end

        begin
          # Reuse the importer internals so persistence stays consistent.
          diff_payloads = importer.send(:fetch_diff_payloads, sha)

          diff_records = []
          commit.transaction do
            diff_records = importer.send(:persist_diff_records, commit, diff_payloads)
          end

          importer.send(:refresh_embedding, commit, diff_records, diff_payloads.size) if embed

          processed << { sha: sha, diff_count: diff_payloads.size }
        rescue StandardError => e
          errors << { sha: sha, error: e.message }
          logger.error("[DataRefresh] Failed to refresh commit diffs for #{sha}: #{e.message}")
        end
      end

      {
        project_path: project_path,
        requested_shas: target_shas,
        processed: processed,
        errors: errors
      }
    end

    def refresh_all(redmine_issues: nil, redmine_wiki: nil, gitlab_commits: nil, gitlab_commit_diffs: nil)
      results = {}

      results[:redmine_issues] = refresh_redmine_issues(**redmine_issues) if redmine_issues
      results[:redmine_wiki] = refresh_redmine_wiki(**redmine_wiki) if redmine_wiki
      results[:gitlab_commits] = refresh_gitlab_commits(**gitlab_commits) if gitlab_commits
      results[:gitlab_commit_diffs] = refresh_gitlab_commit_diffs(**gitlab_commit_diffs) if gitlab_commit_diffs

      results
    end

    private

    attr_reader :logger

    def redmine_config
      Rails.application.config.x.redmine
    end

    def gitlab_config
      Rails.application.config.x.gitlab
    end

    def redmine_client
      @redmine_client ||= Redmine::Client.new(
        base_url: redmine_config.base_url,
        api_key: redmine_config.api_key,
        page_size: redmine_config.issue_limit,
        logger: logger
      )
    end

    def gitlab_client
      @gitlab_client ||= Gitlab::Client.new(
        base_url: gitlab_config.base_url,
        private_token: gitlab_config.private_token,
        per_page: gitlab_config.per_page,
        logger: logger
      )
    end

    def require_gitlab_project_path!
      project_path = gitlab_config.project_path
      raise ArgumentError, "GitLab project path is required" if project_path.blank?

      project_path
    end

    def parse_time(value)
      return if value.blank?
      return value if value.is_a?(Time)

      Time.zone.parse(value.to_s)
    rescue StandardError
      raise ArgumentError, "Invalid timestamp: #{value.inspect}"
    end

    def sanitize_limit(value)
      return nil if value.nil?

      coerced = value.to_i
      coerced.positive? ? coerced : nil
    end

    def boolean_override(default, override)
      return default if override.nil?

      override
    end

    def format_gitlab_results(results)
      Array(results).map do |entry|
        issue = entry.issue
        result = entry.result

        payload_checksum = result.respond_to?(:checksum) ? result.checksum : nil
        error_message = result.is_a?(StandardError) ? result.message : nil

        {
          issue_external_id: issue&.external_id,
          status: entry.status,
          gitlab_issue_iid: issue&.gitlab_issue_iid,
          gitlab_issue_web_url: issue&.gitlab_issue_web_url,
          checksum: payload_checksum,
          error: error_message
        }.compact
      end
    end
  end
end
