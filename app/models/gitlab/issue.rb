# frozen_string_literal: true

module Gitlab
  class Issue < ApplicationRecord
    belongs_to :project, class_name: "Project", optional: true if defined?(Project)
    has_many :embeddings, as: :source, dependent: :destroy

    has_many :issue_labels, inverse_of: :issue, dependent: :destroy, class_name: 'Gitlab::IssueLabel'
    has_many :labels, through: :issue_labels, source: :label

    has_many :issue_assignees, inverse_of: :issue, dependent: :destroy, class_name: 'Gitlab::IssueAssignee'
    has_many :assignees, through: :issue_assignees, source: :assignee

    validates :external_id, :project_identifier, :title, presence: true

    # Returns the current GitLab label names associated with the issue.
    def gitlab_labels
      labels.order(:name).pluck(:name)
    end

    # Replaces the current GitLab labels with the provided set of names.
    def gitlab_labels=(values)
      names = normalize_strings(values)

      if names.empty?
        issue_labels.delete_all
        return []
      end

      label_scope = Gitlab::Label.all
      label_scope = label_scope.for_project(gitlab_issue_project_path) if gitlab_issue_project_path.present?
      matching = label_scope.where(name: names).pluck(:id)

      issue_labels.where.not(label_id: matching).delete_all

      existing = issue_labels.pluck(:label_id)
      (matching - existing).each do |label_id|
        issue_labels.create!(label_id: label_id)
      end

      gitlab_labels
    end

    # Returns the GitLab assignee external IDs linked to the issue.
    def gitlab_assignee_ids
      assignees.pluck(:external_id)
    end

    # Replaces the current GitLab assignee links using GitLab external IDs.
    def gitlab_assignee_ids=(values)
      ids = Array(values).map { |value| value.to_i }.select { |id| id.positive? }.uniq

      if ids.empty?
        issue_assignees.delete_all
        return []
      end

      assignee_records = Gitlab::Assignee.where(external_id: ids)
      assignee_map = assignee_records.index_by { |record| record.external_id.to_i }
      target_ids = assignee_map.values.map(&:id)

      issue_assignees.where.not(assignee_id: target_ids).delete_all

      existing = issue_assignees.pluck(:assignee_id)
      (target_ids - existing).each do |assignee_id|
        issue_assignees.create!(assignee_id: assignee_id)
      end

      gitlab_assignee_ids
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

    def to_gitlab_payload(project_path: nil)
      IssueTransfer::GitlabPayloadBuilder.new(
        issue: self,
        project_path: project_path
      ).call
    end

    def to_gitlab(project_path: nil)
      to_gitlab_payload(project_path: project_path)
    end

    def diff_with_redmine(remote_payload)
      IssueTransfer::Comparator.new(
        local_payload: to_redmine_payload,
        remote_payload: remote_payload
      ).diff
    end

    def diff_with_gitlab(remote_payload, project_path: nil)
      IssueTransfer::Comparator.new(
        local_payload: to_gitlab_payload(project_path: project_path),
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

    def normalize_strings(values)
      Array(values).filter_map do |value|
        string = value.to_s.strip
        string if string.present?
      end.uniq
    end
  end
end
