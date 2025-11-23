# frozen_string_literal: true

module Gitlab
  class IssueLabel < ApplicationRecord
    belongs_to :issue, class_name: 'Gitlab::Issue', inverse_of: :issue_labels
    belongs_to :label, class_name: 'Gitlab::Label', inverse_of: :issue_labels

    validates :label_id, uniqueness: { scope: :issue_id }
  end
end
