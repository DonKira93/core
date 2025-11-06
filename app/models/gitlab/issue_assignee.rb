# frozen_string_literal: true

module Gitlab
  class IssueAssignee < ApplicationRecord
    belongs_to :issue, inverse_of: :issue_assignees
    belongs_to :assignee, inverse_of: :issue_assignees

    validates :assignee_id, uniqueness: { scope: :issue_id }
  end
end
