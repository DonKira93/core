# frozen_string_literal: true

class Issue < ApplicationRecord
  belongs_to :project, class_name: "Project", optional: true if defined?(Project)
  has_many :embeddings, as: :source, dependent: :destroy

  validates :external_id, :project_identifier, :title, presence: true

  def embed_payload
    [
      "Issue ##{external_id} (#{project_identifier})",
      "Title: #{title}",
      ("Tracker: #{tracker}" if tracker.present?),
      ("Status: #{status}" if status.present?),
      ("Priority: #{priority}" if priority.present?),
      ("Assignee: #{assignee_name}" if assignee_name.present?),
      ("Author: #{author_name}" if author_name.present?),
      ("Closed on: #{closed_on}" if closed_on.present?),
      ("Updated on: #{updated_on}" if updated_on.present?),
      "\nDescription:\n#{description}",
    ].compact.join("\n\n")
  end

  def external_url
    base = Rails.application.config.x.redmine.base_url
    return unless base.present?

    URI.join(base.end_with?('/') ? base : "#{base}/", "issues/#{external_id}").to_s
  rescue URI::InvalidURIError
    nil
  end
end
