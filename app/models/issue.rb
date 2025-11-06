# frozen_string_literal: true

class Issue < ApplicationRecord
  belongs_to :project, class_name: "Project", optional: true if defined?(Project)
  has_many :embeddings, as: :source, dependent: :destroy

  validates :external_id, :project_identifier, :title, presence: true

  def gitlab_labels
    value = super
    value.is_a?(Array) ? value : []
  end

  def gitlab_labels=(values)
    normalized = Array(values).filter_map do |value|
      string = value.to_s.strip
      string if string.present?
    end
    super(normalized)
  end

  def gitlab_assignee_ids
    values = super
    return [] if values.blank?

    Array(values).filter_map do |value|
      next if value.blank?

      numeric = value.to_i
      numeric if numeric.positive?
    end.uniq
  end

  def gitlab_assignee_ids=(values)
    normalized = Array(values).filter_map do |value|
      next if value.blank?

      numeric = value.to_i
      numeric if numeric.positive?
    end.uniq
    super(normalized)
  end

  def release_notes_publish=(value)
    boolean = ActiveModel::Type::Boolean.new.cast(value)
    super(boolean)
  end

  def release_notes_publish?
    ActiveModel::Type::Boolean.new.cast(self[:release_notes_publish])
  end

  def to_redmine_payload
    IssueTransfer::RedminePayloadBuilder.new(issue: self).call
  end

  def to_redmine
    to_redmine_payload
  end

  def to_gitlab_payload(label_mapper: nil, assignee_resolver: nil, project_path: nil)
    mapper = label_mapper || default_label_mapper(project_path)
    IssueTransfer::GitlabPayloadBuilder.new(
      issue: self,
      label_mapper: mapper,
      assignee_resolver: assignee_resolver,
      project_path: project_path
    ).call
  end

  def to_gitlab(label_mapper: nil, assignee_resolver: nil, project_path: nil)
    to_gitlab_payload(label_mapper: label_mapper, assignee_resolver: assignee_resolver, project_path: project_path)
  end

  def diff_with_redmine(remote_payload)
    IssueTransfer::Comparator.new(
      local_payload: to_redmine_payload,
      remote_payload: remote_payload
    ).diff
  end

  def diff_with_gitlab(remote_payload, label_mapper: nil, assignee_resolver: nil, project_path: nil)
    IssueTransfer::Comparator.new(
      local_payload: to_gitlab_payload(label_mapper: label_mapper, assignee_resolver: assignee_resolver, project_path: project_path),
      remote_payload: remote_payload
    ).diff
  end

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

  private

  def default_label_mapper(project_path)
    return Gitlab::LabelMapper.new unless defined?(GitlabLabel)

    path = project_path.presence || gitlab_issue_project_path
    available = path.present? ? GitlabLabel.names_for(path) : nil
    Gitlab::LabelMapper.new(available_labels: available)
  rescue StandardError
    Gitlab::LabelMapper.new
  end
end
