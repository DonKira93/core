# frozen_string_literal: true

require "uri"

module Gitlab
  class Commit < ApplicationRecord
    has_many :embeddings, as: :source, dependent: :destroy
    has_many :commit_diffs, inverse_of: :commit, dependent: :destroy

    validates :sha, :project_path, :title, presence: true

    def embed_payload(diffs: nil, total_diff_count: nil)
      details = []
      details << "Commit #{sha} (#{project_path})"
      details << author_line
      details << title
      details << message if message.present?

      diff_snippets = format_diff_snippets(diffs, total_diff_count)
      details << diff_snippets if diff_snippets.present?

      details.compact.join("\n\n")
    end

    def external_url
      return web_url if web_url.present?

      base = Rails.application.config.x.gitlab.base_url
      return unless base.present?

      web_base = base.sub(%r{/api/v4\z}, "")
      URI.join(web_base.end_with?("/") ? web_base : "#{web_base}/", "#{project_path}/-/commit/#{sha}").to_s
    rescue URI::InvalidURIError
      nil
    end

    private

    def author_line
      return unless author_name.present?

      email = author_email.present? ? " <#{author_email}>" : nil
      timestamp = committed_at&.iso8601
      suffix = timestamp ? " at #{timestamp}" : nil
      "Author: #{author_name}#{email}#{suffix}"
    end

    def format_diff_snippets(diffs, total_diff_count)
      records = Array(diffs.presence || commit_diffs.limit(5)).reject(&:blank?)
      return if records.empty?

      lines = records.map(&:embed_snippet)
      total = total_diff_count || (commit_diffs.loaded? ? commit_diffs.size : commit_diffs.count)
      additional = total - records.size if total
      lines << "(+#{additional} more changes)" if additional&.positive?
      "Diff summary:\n" + lines.join("\n\n")
    end
  end
end
