# frozen_string_literal: true

class WikiPage < ApplicationRecord
  has_many :embeddings, as: :source, dependent: :destroy

  validates :external_id, :project_identifier, :title, :slug, presence: true

  def embed_payload
    [
      "Wiki #{title} (#{project_identifier})",
      ("Summary: #{summary}" if summary.present?),
      "\n#{content}"
    ].compact.join("\n\n")
  end

  def external_url
    base = Rails.application.config.x.redmine.base_url
    return unless base.present?

    path = "projects/#{project_identifier}/wiki/#{slug}"
    URI.join(base.end_with?('/') ? base : "#{base}/", path).to_s
  rescue URI::InvalidURIError
    nil
  end
end
