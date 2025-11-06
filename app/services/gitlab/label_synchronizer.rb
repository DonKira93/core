# frozen_string_literal: true

require 'set'

module Gitlab
  class LabelSynchronizer
    def initialize(client:, project_path:, logger: Rails.logger)
      @client = client
      @project_path = project_path
      @logger = logger
    end

    def call
      seen_ids = Set.new
      upserted = 0
      page = 1
      @removed = 0

      loop do
        batch = fetch_page(page)
        labels = batch[:labels]
        break if labels.blank?

        labels.each do |attrs|
          external_id = attrs['id'].to_s
          seen_ids << external_id

          record = Gitlab::Label.find_or_initialize_by(project_path: @project_path, external_id: external_id)
          record.name = attrs['name']
          record.color = attrs['color']
          record.text_color = attrs['text_color']
          record.description = attrs['description']
          record.raw_payload = attrs
          if record.changed?
            record.save!
            upserted += 1
          end
        end

        next_page = batch[:next_page]
        break if next_page.blank?

        page = next_page.to_i
        break if page <= 0
      end

      cleanup_missing(seen_ids)
      total = Gitlab::Label.for_project(@project_path).count
      { upserted: upserted, removed: @removed || 0, total: total }
    end

    private

    def fetch_page(page)
      response = @client.project_labels(project: @project_path, page: page)
      {
        labels: Array(response[:labels]),
        next_page: response[:next_page]
      }
    rescue StandardError => e
      @logger.error("[GitLab] Failed to fetch labels for #{@project_path} page #{page}: #{e.message}")
      raise
    end

    def cleanup_missing(seen_ids)
      scope = Gitlab::Label.where(project_path: @project_path)
      missing = scope.where.not(external_id: seen_ids.to_a)
      @removed = missing.count
      missing.delete_all if @removed.positive?
    end
  end
end
