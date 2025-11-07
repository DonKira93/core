# frozen_string_literal: true

require "json"

class EmbeddingSearchTool < ApplicationTool
  description "Vector search across issues, commit diffs, and wiki pages"

  annotations(
    title: "Knowledge Base Search",
    read_only_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:query).filled(:string).description("What you want to look for")
    optional(:limit).filled(:integer).description("Maximum number of results (default 8, max 25)")
    optional(:rewrite).filled(:bool).description("Let the server rewrite the query for better recall")
    optional(:sources).array(:string).description("Restrict to source types: issue, commit_diff, wiki_page")
  end

  def call(query:, limit: Mcp::Search::EmbeddingSearch::DEFAULT_LIMIT, rewrite: true, sources: [])
    payload = Mcp::Search::EmbeddingSearch.new(
      query: query,
      limit: limit,
      rewrite: rewrite,
      sources: sources
    ).call

    JSON.pretty_generate(payload)
  end
end
