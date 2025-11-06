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

    def find_user(username:)
      return nil if username.blank?

      response = get('users', username: username)
      Array(response.body).first
    rescue Error
      nil
    end

    def search_users(search:)
      return [] if search.blank?

      response = get('users', search: search, per_page: @per_page)
      Array(response.body)
    rescue Error
      []
    end

    def project_labels(project:, page: 1, per_page: @per_page)
      params = {
        per_page: per_page || @per_page,
        page: page
      }

      response = get("projects/#{encode_project(project)}/labels", params)
      {
        labels: Array(response.body),
        next_page: response.headers['x-next-page'].presence,
        total_pages: response.headers['x-total-pages']&.to_i
      }
    end

    def create_issue(project:, params: {})
      path = "projects/#{encode_project(project)}/issues"
      response = post(path, params)
      response.body
    end

    def update_issue(project:, issue_iid:, params: {})
      path = "projects/#{encode_project(project)}/issues/#{issue_iid}"
      response = put(path, params)
      response.body
    end

    def search_issues(project:, search:, scope: nil, state: nil)
      params = {
        per_page: @per_page,
        search: search
      }
      params[:in] = scope if scope.present?
      params[:state] = state if state.present?

      get("projects/#{encode_project(project)}/issues", params).body
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
        error_message = format_error(response)
        @logger.error("[GitLab] GET #{path} failed: #{error_message}")
        raise Error, error_message
      end

      response
    rescue Faraday::Error => e
      @logger.error("[GitLab] GET #{path} failed: #{e.message}")
      raise
    end

    def post(path, body = {})
      response = @connection.post(path) do |req|
        req.headers['PRIVATE-TOKEN'] = @private_token
        req.headers['Accept'] = 'application/json'
        req.body = body.compact
      end
      unless response.success?
        error_message = format_error(response)
        @logger.error("[GitLab] POST #{path} failed: #{error_message}")
        raise Error, error_message
      end

      response
    rescue Faraday::Error => e
      @logger.error("[GitLab] POST #{path} failed: #{e.message}")
      raise
    end

    def put(path, body = {})
      response = @connection.put(path) do |req|
        req.headers['PRIVATE-TOKEN'] = @private_token
        req.headers['Accept'] = 'application/json'
        req.body = body.compact
      end
      unless response.success?
        error_message = format_error(response)
        @logger.error("[GitLab] PUT #{path} failed: #{error_message}")
        raise Error, error_message
      end

      response
    rescue Faraday::Error => e
      @logger.error("[GitLab] PUT #{path} failed: #{e.message}")
      raise
    end

    def encode_project(project)
      ERB::Util.url_encode(project)
    end

    def format_error(response)
      status = response.status
      body = response.body

      detail = if body.is_a?(Hash)
        Array(body['message']).join(', ').presence || body.to_s
      else
        body.to_s
      end

      detail = detail.to_s.strip
      detail = '(no body returned)' if detail.blank?

      "HTTP #{status}: #{detail}"
    end
  end
end
