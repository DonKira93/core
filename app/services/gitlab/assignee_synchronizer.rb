# frozen_string_literal: true

require "set"

module Gitlab
  class AssigneeSynchronizer
    DEFAULT_SCOPE = :project

    def initialize(client:, project_path:, scope: DEFAULT_SCOPE, logger: Rails.logger)
      @client = client
      @project_path = project_path
      @scope = scope
      @logger = logger
    end

    def call
      raise ArgumentError, "Assignee store unavailable" unless assignee_store

      seen = Set.new
      upserted = 0
      page = 1

      loop do
        batch = fetch_members(page)
        members = batch[:members]
        break if members.blank?

        members.each do |payload|
          record = assignee_store.upsert_from_api!(payload)
          next unless record

          seen << record.external_id
          upserted += 1 if record.previous_changes.except(:updated_at).present?
        rescue StandardError => e
          identifier = payload["username"] || payload["name"] || payload["id"] || "unknown"
          @logger.warn("[GitLab] Assignee sync failed for #{identifier}: #{e.message}")
        end

        next_page = batch[:next_page].to_i
        break if next_page <= 0

        page = next_page
      end

      removed = prune_missing(seen)
      { upserted: upserted, removed: removed, total: assignee_store.count }
    end

    private

    def fetch_members(page)
      case @scope
      when :project
        @client.project_members(project: @project_path, page: page)
      else
        raise ArgumentError, "Unsupported scope: #{@scope}"
      end
    rescue StandardError => e
      @logger.error("[GitLab] Failed to fetch assignee members for #{@project_path} page #{page}: #{e.message}")
      raise
    end

    def prune_missing(seen)
      return 0 if seen.empty?

      scope = assignee_store
      missing = scope.where.not(external_id: seen.to_a)
      removed = missing.count
      missing.delete_all if removed.positive?
      removed
    end

    def assignee_store
      @assignee_store ||= begin
        klass = Gitlab::Assignee
        klass.table_exists? ? klass : nil
      rescue NameError, ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        nil
      end
    end
  end
end
