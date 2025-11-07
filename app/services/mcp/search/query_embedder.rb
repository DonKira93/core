# frozen_string_literal: true

module Mcp
  module Search
    class QueryEmbedder
      class << self
        def vector_for(text)
          cleaned = text.to_s.strip
          return if cleaned.blank?

          response = Llm::OllamaClient.embed_text(cleaned)
          vectors = Array(response.vectors)
          vector = vectors.first
          normalize_vector(vector)
        rescue StandardError => e
          Rails.logger.error("[MCP] Embedding failed: #{e.message}")
          nil
        end

        private

        def normalize_vector(vector)
          return if vector.nil?

          array = vector.is_a?(Array) ? vector : Array(vector)
          array = array.map(&:to_f)
          array.any? ? array : nil
        end
      end
    end
  end
end
