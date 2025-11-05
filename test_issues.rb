# frozen_string_literal: true

require 'optparse'

options = {
  limit: 100,
  sort: 'updated_on:asc',
  hours: nil,
  since: nil,
  embed: Rails.application.config.x.redmine.embed
}

OptionParser.new do |opts|
  opts.banner = 'Usage: bundle exec rails runner test_issues.rb [options]'

  opts.on('--limit=N', Integer, 'Maximum number of issues to import (default: 100)') do |value|
    options[:limit] = value
  end

  opts.on('--sort=FIELD', String, "Sort order for Redmine issues, e.g. 'updated_on:desc' (default)") do |value|
    options[:sort] = value
  end

  opts.on('--hours=N', Integer, 'Only import issues updated within the last N hours') do |value|
    options[:hours] = value
  end

  opts.on('--since=TIMESTAMP', String, 'Only import issues updated since the given ISO8601 timestamp') do |value|
    options[:since] = value
  end

  opts.on('--no-embed', 'Skip embedding refresh for imported issues') do
    options[:embed] = false
  end
end.parse!(ARGV)

config = Rails.application.config.x.redmine
base_url = config.base_url
api_key = config.api_key
project_identifier = config.project_identifier
page_size = config.issue_limit

unless base_url.present? && api_key.present? && project_identifier.present?
  raise ArgumentError, 'Please configure REDMINE_URL, REDMINE_API_KEY, and REDMINE_PROJECT_IDENTIFIER before running the importer.'
end

updated_since = options[:since]
updated_since ||= options[:hours]&.hours&.ago

descriptor = {
  limit: options[:limit],
  sort: options[:sort],
  updated_since: (updated_since.respond_to?(:iso8601) ? updated_since.iso8601 : updated_since),
  embed: options[:embed]
}

puts "Starting Redmine issue import with: #{descriptor.compact.inspect}"

client = Redmine::Client.new(
  base_url: base_url,
  api_key: api_key,
  page_size: page_size
)

importer = Redmine::IssueImporter.new(
  client: client,
  project_identifier: project_identifier,
  limit: options[:limit],
  sort: options[:sort],
  embed: options[:embed],
  updated_since: updated_since
)

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
importer.call
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

puts format('Import complete in %.2f seconds.', elapsed)
puts "Issues processed: #{importer.processed_count}"
puts "Total issues stored: #{Issue.where(project_identifier: project_identifier).count}"

if options[:embed]
  embeddings = Embedding.where(source_type: 'Issue', source_id: Issue.select(:id).where(project_identifier: project_identifier))
  puts "Embeddings for project: #{embeddings.count}"
else
  puts 'Embeddings were skipped for this run.'
end
