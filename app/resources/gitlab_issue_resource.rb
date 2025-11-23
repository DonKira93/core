# frozen_string_literal: true

require "json"

class GitlabIssueResource < ApplicationResource
  uri "gitlab/issues/{id}"
  resource_name "GitLab Issue"
  description "Details for a cached GitLab issue synced from Redmine"
  mime_type "application/json"

  def content
    JSON.pretty_generate(serialized_issue)
  end

  private

  def serialized_issue
    issue = locate_issue
    {
      id: issue.id,
      redmine_id: issue.external_id,
      gitlab_issue_iid: issue.gitlab_issue_iid,
      gitlab_issue_project_path: issue.gitlab_issue_project_path,
      title: issue.title,
      status: issue.status,
      priority: issue.priority,
      tracker: issue.tracker,
      assignee_name: issue.assignee_name,
      author_name: issue.author_name,
      labels: issue.gitlab_labels,
      gitlab_assignee_ids: issue.gitlab_assignee_ids,
      updated_on: issue.updated_on,
      description: issue.description,
      release_notes: issue.release_notes,
      external_url: issue.external_url
    }.compact
  end

  def locate_issue
    identifier = params.fetch(:id).to_s.delete_prefix("#")
    record = fetch_by_numeric_id(identifier) || fetch_by_external_id(identifier)
    return record if record

    raise FastMcp::Resource::NotFoundError, "Issue not found"
  end

  def fetch_by_numeric_id(identifier)
    return unless identifier.match?(/\A\d+\z/)

    Gitlab::Issue.find_by(id: identifier.to_i)
  end

  def fetch_by_external_id(identifier)
    Gitlab::Issue.find_by(external_id: identifier)
  end
end
