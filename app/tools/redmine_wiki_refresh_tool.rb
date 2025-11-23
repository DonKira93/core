# frozen_string_literal: true

require "json"

class RedmineWikiRefreshTool < ApplicationTool
  description "Import and embed Redmine wiki pages"

  annotations(
    title: "Refresh Redmine Wiki",
    read_only_hint: false,
    open_world_hint: false
  )

  arguments do
    optional(:project_identifier).filled(:string).description("Redmine project identifier to sync wiki pages from")
    optional(:embed).filled(:bool).description("Refresh embeddings for imported wiki pages (default true)")
  end

  def call(project_identifier: nil, embed: nil)
    coordinator = DataRefresh::Coordinator.new
    result = coordinator.refresh_redmine_wiki(
      project_identifier: project_identifier,
      embed: embed
    )

    JSON.pretty_generate(result)
  rescue StandardError => e
    JSON.pretty_generate(error: e.message)
  end
end
