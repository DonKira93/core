# frozen_string_literal: true

module Mcp
  module Search
    class EmbeddingSearch
      DEFAULT_LIMIT = 8
      MAX_LIMIT = 25

      SOURCE_TYPES = {
        "issue" => "Gitlab::Issue",
        "issues" => "Gitlab::Issue",
        "gitlab_issue" => "Gitlab::Issue",
        "commit" => "Gitlab::CommitDiff",
        "commit_diff" => "Gitlab::CommitDiff",
        "commit_diffs" => "Gitlab::CommitDiff",
        "diff" => "Gitlab::CommitDiff",
        "wiki" => "WikiPage",
        "wiki_page" => "WikiPage",
        "wiki_pages" => "WikiPage"
      }.freeze

      def initialize(query:, limit: DEFAULT_LIMIT, rewrite: true, sources: nil)
        @query = query
        @limit = [limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT, MAX_LIMIT].min
        @rewrite = rewrite
        @sources = Array(sources).compact_blank
      end

      def call
        effective_query = rewrite_query
        vector = Mcp::Search::QueryEmbedder.vector_for(effective_query)
        return build_response(effective_query, []) if vector.blank?

        scope = Embedding.nearest_neighbors(:embedding, vector, distance: "cosine")
        scope = scope.where(source_type: mapped_source_types) if mapped_source_types.present?
        records = scope.includes(:source).limit(@limit)

        results = records.filter_map do |embedding|
          Mcp::Search::ResultPresenter.new(embedding: embedding).to_hash
        end

        build_response(effective_query, results)
      end

      private

      def rewrite_query
        Mcp::Search::QueryRewriter.new(query: @query, enabled: @rewrite).call
      end

      def mapped_source_types
        return @mapped_source_types if defined?(@mapped_source_types)

        @mapped_source_types = @sources.map { |source| SOURCE_TYPES[source.to_s.downcase] }.compact.uniq
      end

      def build_response(effective_query, results)
        {
          original_query: @query,
          effective_query: effective_query,
          limit: @limit,
          total_results: results.size,
          sources_filter: mapped_source_types,
          results: results
        }
      end
    end
  end
end
