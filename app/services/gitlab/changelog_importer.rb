# frozen_string_literal: true

require 'logger'

module Gitlab
  class ChangelogImporter
    attr_reader :processed_count

    def initialize(client:, project_path:, embed: true, logger: Rails.logger, since: nil, limit: nil)
      @client = client
      @project_path = project_path
      @embed = embed
      @logger = logger || Logger.new($stdout)
      @since = parse_since(since)
      @limit = limit
      @processed_count = 0
    end

    def call
      return 0 if limit_reached?

      page = 1
      loop do
        batch = @client.commits(project: @project_path, page: page, since: @since)
        commits = batch[:commits]
        break if commits.blank?

        commits.each do |attrs|
          break if limit_reached?

          upsert_commit(attrs)
        end

        break if limit_reached?
        next_page = batch[:next_page]
        break if next_page.blank?

        page = next_page.to_i
        page = 1 if page <= 0 # guard in case header missing or zero
      end

      processed_count
    end

    private

    def upsert_commit(attrs)
      sha = attrs['id']
      return if sha.blank?

      diff_payloads = fetch_diff_payloads(sha)

      record = Gitlab::Commit.find_or_initialize_by(sha: sha)
      record.project_path = @project_path
      record.title = attrs['title'].presence || attrs['message'].to_s.lines.first&.strip || sha
      record.message = attrs['message']
      record.author_name = attrs['author_name']
      record.author_email = attrs['author_email']
      record.web_url = attrs['web_url']
      record.committed_at = parse_time(attrs['committed_date'])
      record.raw_payload = attrs

      diff_records = []
      record.transaction do
        record.save!
        diff_records = persist_diff_records(record, diff_payloads)
      end

      refresh_embedding(record, diff_records, diff_payloads.size)

      @processed_count += 1
    rescue StandardError => e
      @logger.error("[GitLab] Commit import failed for #{sha}: #{e.message}")
    end

    def refresh_embedding(record, diff_records, diff_count)
      return unless @embed

      Embedding.refresh_for!(
        source: record,
        content: record.embed_payload(diffs: diff_records.first(5), total_diff_count: diff_count),
        metadata: {
          source: 'gitlab_commit',
          sha: record.sha,
          project: record.project_path,
          external_url: record.external_url
        }
      )
    rescue StandardError => e
      @logger.error("[GitLab] Commit embedding failed for #{record.sha}: #{e.message}")
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue StandardError
      nil
    end

    def parse_since(value)
      return if value.blank?
      return value if value.is_a?(Time)

      Time.zone.parse(value.to_s)
    rescue StandardError
      nil
    end

    def fetch_diff_payloads(sha)
      Array(@client.commit_diffs(project: @project_path, sha: sha))
    rescue StandardError => e
      @logger.warn("[GitLab] Diff fetch skipped for #{sha}: #{e.message}")
      []
    end

    def persist_diff_records(record, diff_payloads)
      record.commit_diffs.delete_all
      return [] if diff_payloads.blank?

      diff_payloads.map do |diff|
        record.commit_diffs.create!(
          old_path: diff['old_path'],
          new_path: diff['new_path'],
          new_file: diff['new_file'] || false,
          renamed_file: diff['renamed_file'] || false,
          deleted_file: diff['deleted_file'] || false,
          a_mode: diff['a_mode'],
          b_mode: diff['b_mode'],
          diff_text: diff['diff'],
          raw_payload: diff
        )
      end
    end

    def limit_reached?
      return false if @limit.nil?

      @processed_count >= @limit
    end
  end
end
