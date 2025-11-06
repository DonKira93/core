# frozen_string_literal: true

namespace :redmine do
  module Helpers
    module_function

    def parse_since_argument(since_value, hours_value)
      return since_value if since_value.present?

      return nil if hours_value.blank?

      hours = hours_value.to_i
      return nil if hours <= 0

      hours.hours.ago
    end
  end

  desc "Sync Redmine issues into the local database (Usage: rake redmine:sync_issues[limit,hours])"
  task :sync_issues, [:limit, :hours, :since, :sort, :embed] => :environment do |_, args|
    config = Rails.application.config.x.redmine
    base_url = config.base_url
    api_key = config.api_key
    query_id = config.query_id
    page_size = config.issue_limit

    unless base_url.present? && api_key.present? && query_id.present?
      raise ArgumentError, 'Please configure REDMINE_URL, REDMINE_API_KEY, and REDMINE_QUERY_ID before running redmine:sync_issues.'
    end

    limit = args[:limit].to_i if args[:limit].present?
    limit = nil if limit&.<= 0

    schedule = SyncSchedule.fetch(task_name: 'redmine:sync_issues', scope: query_id)

    explicit_since = Helpers.parse_since_argument(args[:since], args[:hours])
    updated_since = explicit_since || schedule.checkpoint
    sort = args[:sort].presence || 'updated_on:desc'
    embed = args[:embed].nil? ? config.embed : ActiveModel::Type::Boolean.new.cast(args[:embed])

    client = Redmine::Client.new(
      base_url: base_url,
      api_key: api_key,
      page_size: page_size
    )

    importer = Redmine::IssueImporter.new(
      client: client,
      query_id: query_id,
      limit: limit,
      sort: sort,
      embed: embed,
      updated_since: updated_since
    )

    descriptor = {
      limit: limit,
      sort: sort,
      updated_since: updated_since,
      embed: embed
    }.compact

    puts "Starting Redmine issue sync with: #{descriptor.inspect}"

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    schedule.mark_started!

    begin
      importer.call
      schedule.mark_succeeded!
    rescue StandardError => e
      schedule.record_error!(e.message)
      raise
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    puts format('Redmine sync complete in %.2f seconds.', elapsed)
    puts "Issues processed this run: #{importer.processed_count}"
    puts "Total issues stored: #{Issue.count}"
  end
end
