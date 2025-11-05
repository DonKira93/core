# frozen_string_literal: true

module Llm
  class OllamaClient
    Error = Class.new(StandardError)

    class << self
      def chat(prompt, model: default_chat_model, system: nil, temperature: nil, params: {})
        conversation = RubyLLM.chat(model:, provider: :ollama, assume_model_exists: true)
        conversation.with_instructions(system) if system.present?
        conversation.with_temperature(temperature) if temperature
        conversation.with_params(**params) if params.present?

        conversation.ask(prompt)
      rescue StandardError => e
        raise Error, "Ollama chat failed: #{e.message}", cause: e
      end

      def embed_text(text, model: default_embedding_model, dimensions: configured_dimensions)
        RubyLLM.embed(text, provider: :ollama, model:, assume_model_exists: true, dimensions: dimensions)
      rescue StandardError => e
        raise Error, "Ollama embedding failed: #{e.message}", cause: e
      end

      def default_chat_model
        ENV.fetch("OLLAMA_CHAT_MODEL", "llama3.1:8b")
      end

      def default_embedding_model
        ENV.fetch("OLLAMA_EMBEDDING_MODEL", "mahonzhan/all-MiniLM-L6-v2")
      end

      def configured_dimensions
        value = ENV["OLLAMA_EMBEDDING_DIMENSIONS"]
        value.present? ? value.to_i : nil
      end
    end
  end
end
