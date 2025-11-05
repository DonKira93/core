# frozen_string_literal: true
class Embedding < ApplicationRecord
  has_neighbors :embedding, normalize: true
  
  belongs_to :source, polymorphic: true
  
  scope :for_source, ->(source) { where(source:) }

  def embedding
    raw = super
    return if raw.nil?

    raw.is_a?(String) ? Pgvector.decode(raw) : raw
  end

  def embedding=(value)
    encoded =
      case value
      when nil
        nil
      when String
        value
      else
        Pgvector.encode(value)
      end

    super(encoded)
  end

  def self.refresh_for!(source:, content:, metadata: {})
    return if content.blank?

    vector_response = Llm::OllamaClient.embed_text(content)
    vector = vector_response.vectors
    vector = vector.first if vector.respond_to?(:first) && vector.first.is_a?(Array)

    record = Embedding.find_or_initialize_by(source:)
    record.content = content
    record.embedding = vector
    record.metadata = metadata
    record.save!
    record
  rescue StandardError => e
    Rails.logger.error("[Embedding] Failed to refresh for #{source.class.name}##{source.id}: #{e.message}")
    raise
  end
end
