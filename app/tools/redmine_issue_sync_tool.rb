# frozen_string_literal: true

require "json"

class RedmineIssueSyncTool < ApplicationTool
  description "Sync Redmine issues locally and publish updates to GitLab"

  annotations(
    title: "Sync Redmine Issues",
    read_only_hint: false,
    open_world_hint: false
  )

  arguments do
    optional(:since).filled(:string).description("Only import issues updated on or after this timestamp")
    optional(:limit).filled(:integer).description("Cap the number of issues to import")
    optional(:sort).filled(:string).description("Override Redmine sort order, defaults to updated_on:desc")
    optional(:embed).filled(:bool).description("Refresh embeddings for imported issues (default true)")
  end

  def call(since: nil, limit: nil, sort: nil, embed: nil)
    coordinator = DataRefresh::Coordinator.new
    result = coordinator.refresh_redmine_issues(
      since: since,
      limit: limit,
      sort: sort,
      embed: embed
    )

    JSON.pretty_generate(result)
  rescue StandardError => e
    JSON.pretty_generate(error: e.message)
  end
end
