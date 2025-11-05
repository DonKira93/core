# frozen_string_literal: true

require 'optparse'

config = Rails.application.config.x.gitlab

default_options = {
  limit: 100,
  embed: Rails.application.config.x.gitlab.embed,
  project_path: Rails.application.config.x.gitlab.project_path,
  since: nil
}

options = default_options.dup

OptionParser.new do |opts|
  opts.banner = 'Usage: bundle exec rails runner import_gitlab_commits.rb [options]'

  opts.on('--limit=N', Integer, 'Maximum number of commits to import (default: 100)') do |value|
    options[:limit] = value if value&.positive?
  end

  opts.on('--since=TIMESTAMP', String, 'Only import commits since the given ISO8601 timestamp') do |value|
    options[:since] = value
  end

  opts.on('--project=PATH', String, 'Override the GitLab project path (e.g. group/project)') do |value|
    options[:project_path] = value
  end

  opts.on('--no-embed', 'Skip embedding refresh for imported commits') do
    options[:embed] = false
  end
end.parse!(ARGV)

base_url = config.base_url
private_token = config.private_token
project_path = options[:project_path]
limit = options[:limit]

unless base_url.present? && private_token.present? && project_path.present?
  raise ArgumentError, 'Please configure GITLAB_URL, GITLAB_TOKEN, and GITLAB_PROJECT_PATH (or pass --project) before running the importer.'
end

client = Gitlab::Client.new(
  base_url: base_url,
  private_token: private_token,
  per_page: [config.per_page, limit || config.per_page].compact.min
)

importer = Gitlab::ChangelogImporter.new(
  client: client,
  project_path: project_path,
  embed: options[:embed],
  since: options[:since],
  limit: limit
)

descriptor = {
  project: project_path,
  limit: limit,
  since: options[:since],
  embed: options[:embed]
}

puts "Starting GitLab commit import with: #{descriptor.compact.inspect}"

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
processed = importer.call
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

puts format('Commit import complete in %.2f seconds.', elapsed)
puts "Commits processed this run: #{processed}"

total_commits = GitlabCommit.where(project_path: project_path).count
puts "Total commits stored: #{total_commits}"

if options[:embed]
  commit_ids = GitlabCommit.where(project_path: project_path).select(:id)
  embeddings_count = Embedding.where(source_type: 'GitlabCommit', source_id: commit_ids).count
  puts "Embeddings for project: #{embeddings_count}"
else
  puts 'Embeddings were skipped for this run.'
end

puts "Total commit diffs stored: #{GitlabCommitDiff.joins(:gitlab_commit).where(gitlab_commits: { project_path: project_path }).count}"
