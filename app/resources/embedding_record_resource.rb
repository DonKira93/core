# frozen_string_literal: true

require "json"

class EmbeddingRecordResource < ApplicationResource
  uri "embedding-search/{source_type}/{id}"
  resource_name "Embedding Search Record"
  description "Detailed content for an embedding-backed record"
  mime_type "application/json"

  def content
    presenter = build_presenter
    JSON.pretty_generate(presenter.to_resource_hash)
  end

  private

  SOURCE_MAP = {
    "issue" => "Gitlab::Issue",
    "commit_diff" => "Gitlab::CommitDiff",
    "wiki_page" => "WikiPage"
  }.freeze

  def build_presenter
    embedding = source_record.embeddings.order(updated_at: :desc).first
    raise ActiveRecord::RecordNotFound unless embedding
    Mcp::Search::ResultPresenter.new(embedding: embedding, include_content: true)
  rescue ActiveRecord::RecordNotFound
    raise FastMcp::Resource::NotFoundError, "Embedding record not found"
  end

  def source_record
    klass = SOURCE_MAP.fetch(normalized_source_type) { raise FastMcp::Resource::NotFoundError, "Unsupported source type" }
    klass.constantize.find(resource_id)
  rescue ActiveRecord::RecordNotFound
    raise FastMcp::Resource::NotFoundError, "Record not found"
  end

  def normalized_source_type
    params.fetch(:source_type).to_s.downcase
  end

  def resource_id
    params.fetch(:id).to_i
  end
end
