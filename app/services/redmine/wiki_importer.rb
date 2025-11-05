# frozen_string_literal: true

require 'securerandom'
require 'action_view'
require 'logger'

module Redmine
  class WikiImporter
    attr_reader :processed_count

    def initialize(client:, project_identifier:, embed: true, logger: Rails.logger)
      @client = client
      @project_identifier = project_identifier
      @embed = embed
      @logger = logger || Logger.new($stdout)
      @sanitizer = ActionView::Base.full_sanitizer
      @processed_count = 0
    end

    def call
      pages = Array(@client.wiki_index(project: @project_identifier))
      return 0 if pages.empty?

      pages.each do |page|
        next if page['title'].blank?

        fetch_and_upsert(page['title'])
      end

      processed_count
    end

    private

    def fetch_and_upsert(title)
      data = @client.wiki_page(project: @project_identifier, title: title)
      wiki_attrs = data.fetch('wiki_page', {})
      external_id = wiki_attrs['id'].to_s.presence || SecureRandom.uuid

      record = WikiPage.find_or_initialize_by(external_id: external_id)
      record.project_identifier = @project_identifier
      record.title = wiki_attrs['title'].presence || title
      record.slug = (wiki_attrs['title'].presence || title).to_s.parameterize
      record.summary = extract_summary(wiki_attrs)
      record.content = wiki_attrs['text']
      record.updated_on = parse_time(wiki_attrs['updated_on'])
      record.raw_payload = data
      record.save!

      @processed_count += 1

      return unless @embed && record.content.present?

      refresh_embedding(record)
    rescue StandardError => e
      @logger.error("[Redmine] Wiki import failed for '#{title}': #{e.message}")
    end

    def refresh_embedding(record)
      Embedding.refresh_for!(
        source: record,
        content: record.embed_payload,
        metadata: {
          source: 'redmine_wiki',
          external_url: record.external_url,
          project: record.project_identifier
        }
      )
    rescue StandardError => e
      @logger.error("[Redmine] Wiki embedding failed for '#{record.title}': #{e.message}")
    end

    def extract_summary(attrs)
      text = attrs['text']
      return if text.blank?

      stripped = @sanitizer.sanitize(text)
      stripped.truncate(280)
    rescue StandardError
      nil
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue StandardError
      nil
    end
  end
end
