# frozen_string_literal: true

require "ruby_llm"

ollama_base = ENV.fetch("OLLAMA_URL", "http://localhost:11434")
normalized_base = ollama_base.end_with?('/') ? ollama_base.chomp('/') : ollama_base
normalized_base = normalized_base.end_with?('/v1') ? normalized_base : "#{normalized_base}/v1"

RubyLLM.configure do |config|
  config.ollama_api_base = normalized_base

  config.default_model = ENV.fetch("OLLAMA_CHAT_MODEL", "llama3.1:8b")
  config.default_embedding_model = ENV.fetch("OLLAMA_EMBEDDING_MODEL", "mahonzhan/all-MiniLM-L6-v2")

  if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    config.logger = Rails.logger
    config.log_level = Rails.logger.level
  end
end
