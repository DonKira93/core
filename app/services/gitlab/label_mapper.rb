# frozen_string_literal: true

require 'set'

module Gitlab
  class LabelMapper

    def initialize(available_labels: nil)
      @available_labels = normalize_available_labels(available_labels)
    end
    TRACKER_LABELS = {
      'Error' => 'type::error',
      'Änderung' => 'type::change',
      'Neues Feature' => 'type::feature',
      'Zu erledigen' => 'type::task',
      'Test case' => 'type::test'
    }.freeze

    STATUS_LABELS = {
      'Planung' => 'status::planning',
      'Neu' => 'status::new',
      'In Arbeit' => 'status::in-progress',
      'Rückfrage' => 'status::blocked',
      'Merge-Request' => 'status::review',
      'Zu Testen' => 'status::qa',
      'Geschlossen' => 'status::closed'
    }.freeze

    PLANNING_ASSIGNEES = [
      '#support, iq-anae(neues tickets-user)',
      'iq, planung'
    ].freeze

    PRIORITY_LABELS = {
      'Sofort!' => 'priority::0-critical',
      'Dringend' => 'priority::1-urgent',
      'Hoch' => 'priority::2-high',
      'Normal' => 'priority::3-normal',
      'Niedrig' => 'priority::4-low'
    }.freeze

    RELEASE_LABELS = {
      '25.0 (featurefreeze)' => 'release::25-0',
      '25.1 (Prerelease)' => 'release::25-1',
      'Zukunft' => 'release::future'
    }.freeze

    ENVIRONMENT_LABELS = {
      'Featurefreeze' => 'env::featurefreeze',
      'Prerelease' => 'env::prerelease'
    }.freeze

    COMPLEXITY_LABELS = {
      'normal' => 'complexity::normal'
    }.freeze

    def self.planning_assignee?(name)
      return false if name.blank?

      normalized = name.to_s.strip.downcase
      PLANNING_ASSIGNEES.include?(normalized)
    end

    def labels_for(issue)
      labels = []

      labels << TRACKER_LABELS[issue.tracker.to_s]
      labels << STATUS_LABELS[issue.status.to_s] if !self.class.planning_assignee?(issue.assignee_name)
      labels << PRIORITY_LABELS[issue.priority.to_s]

      version_name = issue.fixed_version_name
      labels << RELEASE_LABELS[version_name.to_s] if version_name

      valid_for = issue.valid_for
      labels << ENVIRONMENT_LABELS[valid_for.to_s] if valid_for

      complexity = issue.complexity
      labels << COMPLEXITY_LABELS[complexity.to_s]

      labels << 'status::planning' if self.class.planning_assignee?(issue.assignee_name)

      filter_existing(labels.compact.uniq)
    end

    private

    def normalize_available_labels(values)
      return nil if values.blank?

      Set.new(Array(values).filter_map do |value|
        normalized = value.to_s.strip
        normalized if normalized.present?
      end)
    end

    def filter_existing(labels)
      return labels unless @available_labels

      labels.select { |label| @available_labels.include?(label) }
    end
  end
end
