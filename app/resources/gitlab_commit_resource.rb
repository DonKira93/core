# frozen_string_literal: true

require "json"

class GitlabCommitResource < ApplicationResource
  uri "gitlab/commits/{id}"
  resource_name "GitLab Commit"
  description "Details for a cached GitLab commit"
  mime_type "application/json"

  def content
    JSON.pretty_generate(serialized_commit)
  end

  private

  def serialized_commit
    commit = locate_commit
    {
      id: commit.id,
      sha: commit.sha,
      project_path: commit.project_path,
      title: commit.title,
      message: commit.message,
      author_name: commit.author_name,
      author_email: commit.author_email,
      committed_at: commit.committed_at,
      web_url: commit.web_url,
      external_url: commit.external_url,
      diff_ids: commit.commit_diffs.order(:id).limit(25).pluck(:id)
    }.compact
  end

  def locate_commit
    identifier = params.fetch(:id).to_s
    find_by_sha(identifier) || find_by_numeric_id(identifier) || raise(FastMcp::Resource::NotFoundError, "Commit not found")
  end

  def find_by_sha(identifier)
    value = identifier.strip
    return if value.blank?

    direct = Gitlab::Commit.find_by(sha: value)
    return direct if direct

    return unless value.match?(/\A[0-9a-f]+\z/i) && value.length >= 7

    Gitlab::Commit.where("sha LIKE ?", "#{value}%").order(:committed_at).first
  end

  def find_by_numeric_id(identifier)
    return unless identifier.match?(/\A\d+\z/)

    Gitlab::Commit.find_by(id: identifier.to_i)
  end
end
