# frozen_string_literal: true

require 'optparse'

options = {
  embed: Rails.application.config.x.redmine.embed,
  project_identifier: Rails.application.config.x.redmine.project_identifier
}

OptionParser.new do |opts|
  opts.banner = 'Usage: bundle exec rails runner import_wiki.rb [options]'

  opts.on('--project=IDENTIFIER', String, 'Override the Redmine project identifier') do |value|
    options[:project_identifier] = value
  end

  opts.on('--no-embed', 'Skip embedding refresh for imported wiki pages') do
    options[:embed] = false
  end
end.parse!(ARGV)

config = Rails.application.config.x.redmine
base_url = config.base_url
api_key = config.api_key
project_identifier = options[:project_identifier]

unless base_url.present? && api_key.present? && project_identifier.present?
  raise ArgumentError, 'Please configure REDMINE_URL, REDMINE_API_KEY, and specify a project identifier before running the wiki importer.'
end

client = Redmine::Client.new(
  base_url: base_url,
  api_key: api_key,
  page_size: config.issue_limit
)

importer = Redmine::WikiImporter.new(
  client: client,
  project_identifier: project_identifier,
  embed: options[:embed]
)

descriptor = {
  project: project_identifier,
  embed: options[:embed]
}

puts "Starting Redmine wiki import with: #{descriptor.inspect}"

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
processed = importer.call
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

puts format('Wiki import complete in %.2f seconds.', elapsed)
puts "Pages processed this run: #{processed}"

total_pages = WikiPage.where(project_identifier: project_identifier).count
puts "Total wiki pages stored: #{total_pages}"

if options[:embed]
  page_ids = WikiPage.where(project_identifier: project_identifier).select(:id)
  embeddings_count = Embedding.where(source_type: 'WikiPage', source_id: page_ids).count
  puts "Embeddings for project: #{embeddings_count}"
else
  puts 'Embeddings were skipped for this run.'
end
