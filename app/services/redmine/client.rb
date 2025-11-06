# frozen_string_literal: true

require 'erb'

module Redmine
  class Error < StandardError; end

  class Client
    DEFAULT_PAGE_SIZE = 100

    attr_reader :page_size

    def initialize(base_url:, api_key:, page_size: DEFAULT_PAGE_SIZE, logger: Rails.logger)
      @base_url = base_url&.chomp('/')
      @api_key = api_key
      @page_size = page_size.presence || DEFAULT_PAGE_SIZE
      @logger = logger
      raise ArgumentError, "Redmine base URL is required" if @base_url.blank?
      raise ArgumentError, "Redmine API key is required" if @api_key.blank?

      @connection = Faraday.new(@base_url) do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /json/
        faraday.request :retry, max: 3, interval: 0.25, backoff_factor: 2
        faraday.adapter Faraday.default_adapter
      end
    end

    def issues(query_id:, offset: 0, updated_since: nil, sort: nil, limit: nil)
      raise ArgumentError, "Redmine query ID is required" if query_id.blank?

      query = {
        limit: limit || @page_size,
        offset: offset,
        include: 'journals,attachments',
        query_id: query_id
      }

      query[:updated_on] = ">=#{updated_since.utc.iso8601}" if updated_since
      query[:sort] = sort if sort.present?

      response = get('/issues.json', query)
      {
        issues: response.fetch('issues', []),
        total_count: response['total_count'].to_i
      }
    end

    def wiki_index(project:)
      get("/projects/#{project}/wiki/index.json").fetch('wiki_pages', [])
    end

    def wiki_page(project:, title:)
      get("/projects/#{project}/wiki/#{ERB::Util.url_encode(title)}.json", include: 'attachments')
    end

    private

    def get(path, params = {})
      response = @connection.get(path, params) do |req|
        req.headers['X-Redmine-API-Key'] = @api_key
        req.headers['Accept'] = 'application/json'
      end
      handle_response(response)
    rescue Faraday::Error => e
      @logger.error("[Redmine] GET #{path} failed: #{e.message}")
      raise
    end

    def handle_response(response)
      status = response.status.to_i
      body = response.body

      unless response.success?
        message = extract_error_message(body) || "HTTP #{status}"
        raise Redmine::Error, message
      end

      if body.is_a?(Hash)
        error_msg = extract_error_message(body)
        raise Redmine::Error, error_msg if error_msg
      end

      body
    end

    def extract_error_message(body)
      return if body.blank?

      if body.is_a?(Hash)
        errors = body['errors']
        return errors.join(', ') if errors.respond_to?(:join)
        return errors.to_s if errors.present?

        error = body['error']
        return error if error.present?

        message = body['message']
        return message if message.present?

        return nil
      end

      body.is_a?(String) ? body.presence : body.to_s.presence
    end

  end
end
