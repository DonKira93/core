# frozen_string_literal: true

require "json"

class GitlabCommitRefreshTool < ApplicationTool
  description "Ingest GitLab commits (including diffs) into the local cache"

  annotations(
    title: "Refresh GitLab Commits",
    read_only_hint: false,
    open_world_hint: false
  )

  arguments do
    optional(:since).filled(:string).description("Only import commits newer than this timestamp")
    optional(:limit).filled(:integer).description("Cap the number of commits to import")
    optional(:embed).filled(:bool).description("Refresh embeddings for imported commits (default true)")
  end

  def call(since: nil, limit: nil, embed: nil)
    coordinator = DataRefresh::Coordinator.new
    result = coordinator.refresh_gitlab_commits(
      since: since,
      limit: limit,
      embed: embed
    )

    JSON.pretty_generate(result)
  rescue StandardError => e
    JSON.pretty_generate(error: e.message)
  end
end
