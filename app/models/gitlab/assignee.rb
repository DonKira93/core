# frozen_string_literal: true

module Gitlab
  class Assignee < ApplicationRecord
    has_many :issue_assignees, inverse_of: :assignee, dependent: :destroy
    has_many :issues, through: :issue_assignees, source: :issue

    validates :external_id, presence: true, uniqueness: true
    validates :username, presence: true

    scope :by_username, ->(username) {
      where("lower(username) = ?", username.to_s.strip.downcase)
    }

    scope :by_full_name, ->(full_name) {
      where("lower(name) = ?", full_name.to_s.strip.downcase)
    }

    def self.lookup_by_username(username)
      return if username.blank?

      by_username(username).first
    end

    def self.lookup_by_full_name(full_name)
      return if full_name.blank?

      by_full_name(full_name).first
    end

    def self.upsert_from_api!(payload)
      return unless payload

      external_id = payload["id"].to_i
      return if external_id <= 0

      username = payload["username"].presence || payload["name"]
      return unless username.present?

      attributes = {
        external_id: external_id,
        username: username&.strip,
        name: payload["name"].presence&.strip,
        email: payload["email"].presence&.strip,
        state: payload["state"],
        avatar_url: payload["avatar_url"],
        last_synced_at: Time.current
      }.compact

      record = find_or_initialize_by(external_id: external_id)
      record.assign_attributes(attributes)
      record.save!
      record
    end
  end
end
