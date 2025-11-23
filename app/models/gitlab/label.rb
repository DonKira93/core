# frozen_string_literal: true

module Gitlab
  class Label < ApplicationRecord
    TRACKER_LABELS = {
      "Error" => "type::error",
      "Änderung" => "type::change",
      "Neues Feature" => "type::feature",
      "Zu erledigen" => "type::task",
      "Test case" => "type::test"
    }.freeze

    STATUS_LABELS = {
      "Planung" => "status::planning",
      "Neu" => "status::new",
      "In Arbeit" => "status::in-progress",
      "Rückfrage" => "status::blocked",
      "Merge-Request" => "status::review",
      "Zu Testen" => "status::qa",
      "Geschlossen" => "status::closed"
    }.freeze

    PRIORITY_LABELS = {
      "Sofort!" => "priority::0-critical",
      "Dringend" => "priority::1-urgent",
      "Hoch" => "priority::2-high",
      "Normal" => "priority::3-normal",
      "Niedrig" => "priority::4-low"
    }.freeze

    RELEASE_LABELS = {
      "25.0 (featurefreeze)" => "release::25-0",
      "25.1 (Prerelease)" => "release::25-1",
      "Zukunft" => "release::future"
    }.freeze

    ENVIRONMENT_LABELS = {
      "Featurefreeze" => "env::featurefreeze",
      "Prerelease" => "env::prerelease"
    }.freeze

    COMPLEXITY_LABELS = {
      "normal" => "complexity::normal"
    }.freeze

    has_many :issue_labels, inverse_of: :label, dependent: :destroy, class_name: 'Gitlab::IssueLabel'
    has_many :issues, through: :issue_labels, source: :issue

    PLANNING_ASSIGNEES = [
      "#support, iq-anae(neues tickets-user)",
      "iq, planung"
    ].map(&:downcase).freeze

    validates :project_path, :external_id, :name, presence: true
    validates :external_id, uniqueness: { scope: :project_path }

    scope :for_project, ->(path) { where(project_path: path) }

    class << self
      def names_for(project_path)
        return [] if project_path.blank?

        for_project(project_path).pluck(:name)
      end

      def labels_for_issue(issue, project_path: nil)
        labels = build_labels(issue)

        path = project_path.presence || project_path_from_issue(issue)
        return labels if path.blank?

        available = names_for(path)
        return labels if available.blank?

        labels & available
      end

      def planning_assignee?(name)
        return false if name.blank?

        PLANNING_ASSIGNEES.include?(name.to_s.strip.downcase)
      end

      private

      def build_labels(issue)
        labels = []

        tracker = string_value(issue, :tracker)
        labels << TRACKER_LABELS[tracker]

        planning = planning_assignee?(string_value(issue, :assignee_name))
        status = string_value(issue, :status)
        labels << STATUS_LABELS[status] unless planning

        priority = string_value(issue, :priority)
        labels << PRIORITY_LABELS[priority]

        version = string_value(issue, :fixed_version_name)
        labels << RELEASE_LABELS[version] if version

        environment = string_value(issue, :valid_for)
        labels << ENVIRONMENT_LABELS[environment] if environment

        complexity = string_value(issue, :complexity)
        labels << COMPLEXITY_LABELS[complexity]

        labels << "status::planning" if planning

        labels.compact.uniq
      end

      def project_path_from_issue(issue)
        return unless issue.respond_to?(:gitlab_issue_project_path)

        path = issue.gitlab_issue_project_path
        path.presence
      end

      def string_value(issue, attribute)
        return unless issue.respond_to?(attribute)

        value = issue.public_send(attribute)
        value.to_s.strip.presence
      end
    end
  end
end
