# frozen_string_literal: true

class GitlabLabel < ApplicationRecord
  validates :project_path, :external_id, :name, presence: true
  validates :external_id, uniqueness: { scope: :project_path }

  scope :for_project, ->(path) { where(project_path: path) }

  def self.names_for(project_path)
    for_project(project_path).pluck(:name)
  end
end
