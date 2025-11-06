# frozen_string_literal: true

namespace :gitlab do
  desc "Publish Redmine issues to GitLab (Usage: rake gitlab:push_issues[10])"
  task :push_issues, [:limit] => :environment do |_, args|
    limit = args[:limit].to_i
    limit = 10 if limit <= 0

    config = Rails.application.config.x.gitlab
    base_url = config.base_url
    private_token = config.private_token
    project_path = config.project_path

    unless base_url.present? && private_token.present? && project_path.present?
      raise ArgumentError, 'Please configure GITLAB_URL, GITLAB_TOKEN, and GITLAB_PROJECT_PATH before running gitlab:push_issues.'
    end

    client = Gitlab::Client.new(
      base_url: base_url,
      private_token: private_token,
      per_page: config.per_page
    )

    publisher = Gitlab::IssuePublisher.new(
      client: client,
      project_path: project_path
    )

    issues = Gitlab::Issue.order(updated_on: :desc).limit(limit)

    if issues.empty?
      puts 'No issues found to publish.'
    else
      created = 0
      updated_count = 0
      skipped = 0
      failures = []

      issues.each do |issue|
        begin
          result = publisher.publish(issue)
          issue.reload
          iid = issue.gitlab_issue_iid || result.response&.dig('iid') || result.response&.dig('id') || 'unknown'

          case result.status
          when :created
            puts "\u2713 Redmine ##{issue.external_id} -> created GitLab ##{iid}"
            created += 1
          when :updated
            puts "\u2713 Redmine ##{issue.external_id} -> updated GitLab ##{iid}"
            updated_count += 1
          when :skipped
            puts "- Redmine ##{issue.external_id} -> no GitLab changes (##{iid})"
            skipped += 1
          else
            puts "? Redmine ##{issue.external_id} -> processed (status: #{result.status})"
            skipped += 1
          end
        rescue StandardError => e
          warn "\u2717 Redmine ##{issue.external_id} failed: #{e.message}"
          failures << issue.external_id
        end
      end

      puts "Finished. Created: #{created}, Updated: #{updated_count}, Skipped: #{skipped}, Total considered: #{issues.length}."
      puts "Failed external IDs: #{failures.join(', ')}" if failures.any?
    end
  end

  desc 'Sync GitLab project labels into the local cache'
  task :sync_labels, [:project] => :environment do |_, args|
    config = Rails.application.config.x.gitlab
    base_url = config.base_url
    private_token = config.private_token
    project_path = args[:project].presence || config.project_path

    unless base_url.present? && private_token.present? && project_path.present?
      raise ArgumentError, 'Please configure GITLAB_URL, GITLAB_TOKEN, and provide GITLAB_PROJECT_PATH (or pass project) before running gitlab:sync_labels.'
    end

    client = Gitlab::Client.new(
      base_url: base_url,
      private_token: private_token,
      per_page: config.per_page
    )

    synchronizer = Gitlab::LabelSynchronizer.new(
      client: client,
      project_path: project_path
    )

    result = synchronizer.call
    puts "Labels synced for #{project_path}."
    puts "  Upserted: #{result[:upserted]}"
    puts "  Removed: #{result[:removed]}"
    puts "  Total known: #{result[:total]}"
  end

  desc 'Sync GitLab project members into the local assignee cache'
  task :sync_assignees, [:project] => :environment do |_, args|
    unless defined?(Gitlab::Assignee)
      warn 'Gitlab::Assignee model is not available; aborting.'
      next
    end

    config = Rails.application.config.x.gitlab
    base_url = config.base_url
    private_token = config.private_token
    project_path = args[:project].presence || config.project_path

    unless base_url.present? && private_token.present? && project_path.present?
      raise ArgumentError, 'Please configure GITLAB_URL, GITLAB_TOKEN, and provide GITLAB_PROJECT_PATH (or pass project) before running gitlab:sync_assignees.'
    end

    client = Gitlab::Client.new(
      base_url: base_url,
      private_token: private_token,
      per_page: config.per_page
    )

    synchronizer = Gitlab::AssigneeSynchronizer.new(
      client: client,
      project_path: project_path
    )

    result = synchronizer.call
    puts "Assignees synced for #{project_path}."
    puts "  Upserted: #{result[:upserted]}"
    puts "  Removed: #{result[:removed]}"
    puts "  Total known: #{result[:total]}"
  end
end
