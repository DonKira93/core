# frozen_string_literal: true

require "json"

class GitlabCommitDiffResource < ApplicationResource
  uri "gitlab/commit-diffs/{id}"
  resource_name "GitLab Commit Diff"
  description "Detailed diff content for a GitLab commit file change"
  mime_type "application/json"

  def content
    JSON.pretty_generate(serialized_diff)
  end

  private

  def serialized_diff
    diff = locate_diff
    commit = diff.commit
    {
      id: diff.id,
      commit_id: diff.commit_id,
      commit_sha: commit&.sha,
      project_path: commit&.project_path,
      change_type: diff.change_label,
      old_path: diff.old_path,
      new_path: diff.new_path,
      diff_text: diff.diff_text,
      new_file: diff.new_file?,
      renamed_file: diff.renamed_file?,
      deleted_file: diff.deleted_file?
    }.compact
  end

  def locate_diff
    identifier = params.fetch(:id).to_s
    return Gitlab::CommitDiff.find(identifier.to_i) if identifier.match?(/\A\d+\z/)

    raise FastMcp::Resource::NotFoundError, "Commit diff not found"
  rescue ActiveRecord::RecordNotFound
    raise FastMcp::Resource::NotFoundError, "Commit diff not found"
  end
end
