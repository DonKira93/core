# frozen_string_literal: true

require "json"

class GitlabCommitDiffRefreshTool < ApplicationTool
  description "Re-fetch and re-embed GitLab commit diffs"

  annotations(
    title: "Refresh Commit Diffs",
    read_only_hint: false,
    open_world_hint: false
  )

  arguments do
    optional(:shas).array(:string).description("Specific commit SHAs to refresh")
    optional(:limit).filled(:integer).description("If no SHAs provided, refresh the most recent N commits")
    optional(:embed).filled(:bool).description("Refresh embeddings after updating diffs (default true)")
  end

  def call(shas: nil, limit: nil, embed: nil)
    coordinator = DataRefresh::Coordinator.new
    result = coordinator.refresh_gitlab_commit_diffs(
      shas: shas,
      limit: limit,
      embed: embed
    )

    JSON.pretty_generate(result)
  rescue StandardError => e
    JSON.pretty_generate(error: e.message)
  end
end
