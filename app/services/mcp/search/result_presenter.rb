# frozen_string_literal: true

module Mcp
  module Search
    class ResultPresenter
      RESOURCE_SCHEME = "embedding-search".freeze

      def initialize(embedding:, include_content: false)
        @embedding = embedding
        @include_content = include_content
        @source = embedding.source
      end

      def to_hash
        return {} unless @source

        base_payload.merge(extra_payload).compact
      end

      def to_resource_hash
        to_hash.merge(content: resource_content)
      end

      private

      def base_payload
        {
          embedding_id: @embedding.id,
          source_type: normalized_source_type,
          source_id: @source.id,
          resource_uri: resource_uri,
          distance: @embedding.try(:neighbor_distance),
          similarity: similarity_score,
          preview: preview,
          metadata: metadata
        }
      end

      def extra_payload
        case @source
        when Gitlab::Issue
          issue_payload(@source)
        when Gitlab::CommitDiff
          commit_diff_payload(@source)
        when WikiPage
          wiki_payload(@source)
        else
          { title: @source.try(:title) }
        end
      end

      def issue_payload(issue)
        {
          title: issue.title,
          status: issue.status,
          priority: issue.priority,
          labels: issue.gitlab_labels,
          assignee: issue.assignee_name,
          project_identifier: issue.project_identifier,
          external_url: issue.external_url
        }
      end

      def commit_diff_payload(diff)
        commit = diff.commit
        {
          title: diff.display_path,
          change_type: diff.change_label,
          commit_sha: commit&.sha,
          project_path: commit&.project_path,
          commit_title: commit&.title,
          external_url: commit&.external_url
        }
      end

      def wiki_payload(page)
        {
          title: page.title,
          project_identifier: page.project_identifier,
          external_url: page.external_url
        }
      end

      def similarity_score
        distance = @embedding.try(:neighbor_distance)
        return unless distance

        score = 1 - distance.to_f
        score = 0 if score.negative?
        score = 1 if score > 1
        score.round(4)
      end

      def preview
        return unless @embedding.content.present?

        snippet = @embedding.content.to_s.strip
        include_content? ? snippet : snippet.truncate(400)
      end

      def metadata
        raw = @embedding.metadata.presence || {}
        data = raw.deep_dup
        timestamp = metadata_timestamp
        data[:updated_at] = timestamp if timestamp
        data.presence
      end

      def metadata_timestamp
        source_time = if @source.respond_to?(:updated_at)
                        @source.updated_at
                      elsif @source.respond_to?(:created_at)
                        @source.created_at
                      end
        source_time&.iso8601
      end

      def normalized_source_type
        case @source
        when Gitlab::Issue
          "issue"
        when Gitlab::CommitDiff
          "commit_diff"
        when WikiPage
          "wiki_page"
        else
          @source.class.name.underscore
        end
      end

      def resource_uri
        "#{RESOURCE_SCHEME}:///#{normalized_source_type}/#{@source.id}"
      end

      def resource_content
        {
          content: @embedding.content,
          metadata: metadata,
          source_payload: extra_payload
        }
      end

      def include_content?
        @include_content
      end
    end
  end
end
