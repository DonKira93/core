# frozen_string_literal: true

require 'erb'
require 'logger'

module Gitlab
  class Client
    DEFAULT_PER_PAGE = 100
    Error = Class.new(StandardError)

    def initialize(base_url:, private_token:, per_page: DEFAULT_PER_PAGE, logger: Rails.logger)
      @base_url = normalize_base_url(base_url)
      @private_token = private_token
      @per_page = per_page.presence || DEFAULT_PER_PAGE
      @logger = logger || Logger.new($stdout)

      raise ArgumentError, "GitLab base URL is required" if @base_url.blank?
      raise ArgumentError, "GitLab private token is required" if @private_token.blank?

      @connection = Faraday.new(@base_url) do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /json/
        faraday.request :retry, max: 3, interval: 0.25, backoff_factor: 2
        faraday.adapter Faraday.default_adapter
      end
    end

    def commits(project:, page: 1, since: nil, until_time: nil)
      params = {
        per_page: @per_page,
        page: page
      }
      params[:since] = since.iso8601 if since
      params[:until] = until_time.iso8601 if until_time

      response = get("projects/#{encode_project(project)}/repository/commits", params)
      {
        commits: Array(response.body),
        next_page: response.headers['x-next-page'].presence,
        total_pages: response.headers['x-total-pages']&.to_i
      }
    end

    def commit(project:, sha:)
      get("projects/#{encode_project(project)}/repository/commits/#{sha}").body
    end

    def commit_diffs(project:, sha:)
      get("projects/#{encode_project(project)}/repository/commits/#{sha}/diff").body
    end

    private

    def normalize_base_url(url)
      return nil if url.blank?

      normalized = url.chomp('/').to_s
      return normalized if normalized.match?(%r{/api/v\d+\z})

      "#{normalized}/api/v4"
    end

    def get(path, params = {})
      response = @connection.get(path, params) do |req|
        req.headers['PRIVATE-TOKEN'] = @private_token
        req.headers['Accept'] = 'application/json'
      end
      unless response.success?
        @logger.error("[GitLab] GET #{path} failed with status #{response.status}: #{response.body}")
        raise Error, "GitLab API request failed with status #{response.status}"
      end

      response
    rescue Faraday::Error => e
      @logger.error("[GitLab] GET #{path} failed: #{e.message}")
      raise
    end

    def encode_project(project)
      ERB::Util.url_encode(project)
    end
  end
end
