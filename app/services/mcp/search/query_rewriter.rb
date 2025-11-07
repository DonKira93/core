# frozen_string_literal: true

module Mcp
  module Search
    class QueryRewriter
      DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
        You rewrite short search queries to maximize semantic retrieval accuracy across a knowledge base of commit diffs, issues, and wiki pages.
        Keep the wording concise. Expand abbreviations and add context when obviously missing.
        Return only the rewritten query text. If the original query is already clear, return it unchanged.
      PROMPT

      def initialize(query:, enabled: true, model: ENV["MCP_QUERY_REWRITE_MODEL"], system_prompt: ENV["MCP_QUERY_REWRITE_SYSTEM"])
        @query = query.to_s.strip
        @enabled = enabled
        @model = model.presence
        @system_prompt = system_prompt.presence || DEFAULT_SYSTEM_PROMPT
      end

      def call
        return @query if @query.blank? || !enabled?

        response = Llm::OllamaClient.chat(@query, model: target_model, system: @system_prompt)
        rewritten = response.to_s.strip
        rewritten.presence || @query
      rescue StandardError => e
        Rails.logger.warn("[MCP] Query rewrite failed: #{e.message}")
        @query
      end

      private

      def enabled?
        @enabled && target_model.present?
      end

      def target_model
        @model.presence || Llm::OllamaClient.default_chat_model
      end
    end
  end
end
