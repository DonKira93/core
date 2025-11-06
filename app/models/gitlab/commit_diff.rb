# frozen_string_literal: true

module Gitlab
  class CommitDiff < ApplicationRecord
    belongs_to :commit, inverse_of: :commit_diffs

    validates :raw_payload, presence: true

    def change_label
      return "renamed" if renamed_file?
      return "deleted" if deleted_file?
      return "added" if new_file?

      "modified"
    end

    def display_path
      return new_path if new_path.present?
      return old_path if old_path.present?

      "(unknown path)"
    end

    def embed_snippet(max_lines: 40)
      header = "#{change_label} #{display_path}"
      body = diff_text.to_s.lines.first(max_lines).join
      [header, body.presence].compact.join("\n")
    end
  end
end
