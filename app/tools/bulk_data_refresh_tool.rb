# frozen_string_literal: true

require "json"

class BulkDataRefreshTool < ApplicationTool
  description "Run multiple data refresh operations sequentially"

  annotations(
    title: "Refresh Everything",
    read_only_hint: false,
    open_world_hint: false
  )

  ALLOWED_OPERATIONS = %w[redmine_issues redmine_wiki gitlab_commits gitlab_commit_diffs].freeze

  arguments do
    optional(:operations).array(:string).description("Subset of operations to run (default: all)")
    optional(:redmine_since).filled(:string).description("Override Redmine issue sync lower bound timestamp")
    optional(:redmine_limit).filled(:integer).description("Cap Redmine issue imports")
    optional(:redmine_sort).filled(:string).description("Override Redmine sort order")
    optional(:redmine_embed).filled(:bool).description("Refresh embeddings for issues (default true)")
    optional(:wiki_project).filled(:string).description("Redmine wiki project identifier override")
    optional(:wiki_embed).filled(:bool).description("Refresh embeddings for wiki pages (default true)")
    optional(:gitlab_since).filled(:string).description("Override GitLab commit import lower bound timestamp")
    optional(:gitlab_limit).filled(:integer).description("Cap GitLab commit imports")
    optional(:gitlab_embed).filled(:bool).description("Refresh embeddings for commits (default true)")
    optional(:commit_diff_shas).array(:string).description("Explicit list of GitLab commit SHAs for diff refresh")
    optional(:commit_diff_limit).filled(:integer).description("If no SHAs supplied, refresh this many recent commits (default 400)")
    optional(:commit_diff_embed).filled(:bool).description("Refresh embeddings when updating diffs (default true)")
  end

  def call(
    operations: nil,
    redmine_since: nil,
    redmine_limit: nil,
    redmine_sort: nil,
    redmine_embed: nil,
    wiki_project: nil,
    wiki_embed: nil,
    gitlab_since: nil,
    gitlab_limit: nil,
    gitlab_embed: nil,
    commit_diff_shas: nil,
    commit_diff_limit: nil,
    commit_diff_embed: nil
  )
    coordinator = DataRefresh::Coordinator.new

    requested_ops = normalize_operations(operations)
    results = {}

    unknown_ops = requested_ops - ALLOWED_OPERATIONS
    unknown_ops.each do |op|
      results[op.to_sym] = { error: "Unknown operation" }
    end

    valid_ops = (requested_ops & ALLOWED_OPERATIONS)
    valid_ops = ALLOWED_OPERATIONS if valid_ops.empty?

    issue_options = {
      since: redmine_since,
      limit: redmine_limit,
      sort: redmine_sort,
      embed: redmine_embed
    }.compact

    wiki_options = {
      project_identifier: wiki_project,
      embed: wiki_embed
    }.compact

    commit_options = {
      since: gitlab_since,
      limit: gitlab_limit,
      embed: gitlab_embed
    }.compact

    diff_options = {
      shas: commit_diff_shas,
      limit: commit_diff_limit,
      embed: commit_diff_embed
    }.compact

    refresh_results = coordinator.refresh_all(
      redmine_issues: valid_ops.include?("redmine_issues") ? issue_options : nil,
      redmine_wiki: valid_ops.include?("redmine_wiki") ? wiki_options : nil,
      gitlab_commits: valid_ops.include?("gitlab_commits") ? commit_options : nil,
      gitlab_commit_diffs: valid_ops.include?("gitlab_commit_diffs") ? diff_options : nil
    )

    results.merge!(refresh_results)

    JSON.pretty_generate(results)
  rescue StandardError => e
    JSON.pretty_generate(error: e.message)
  end

  private

  def normalize_operations(operations)
    Array(operations).flat_map do |operation|
      operation.to_s.split(',')
    end.map(&:strip).reject(&:empty?).map(&:downcase)
  end
end
