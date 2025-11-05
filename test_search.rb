# frozen_string_literal: true

# Usage: bundle exec rails runner test_search.rb
# Runs a few sample semantic searches against commits, wiki pages, and issues.

QUERIES = [
  "database migration errors",
  "deployment checklist",
  "API authentication bug"
].freeze

RESULT_LIMIT = 5

module SearchRunner
  module_function

  def run
    QUERIES.each do |query|
      puts "\n=== Query: #{query}"
      vector = embed_query(query)
      if vector.blank?
        puts "Skipping query; embedding failed"
        next
      end

      display_results("GitLab commits", fetch_commit_results(vector)) do |record, embedding|
        diffs = record.diffs.limit(2).map(&:embed_snippet).compact
        puts <<~TEXT
          - #{record.sha} (#{record.project_path})
            score: #{format('%.4f', embedding.neighbor_distance.to_f)}
            title: #{record.title.to_s.truncate(140)}
            url: #{record.external_url}
            diff snippet:
            #{diffs.join("\n---\n") if diffs.present?}
        TEXT
      end

      display_results("Wiki pages", fetch_wiki_results(vector)) do |record, embedding|
        puts <<~TEXT
          - #{record.title} (#{record.project_identifier})
            score: #{format('%.4f', embedding.neighbor_distance.to_f)}
            summary: #{record.summary.to_s.truncate(140)}
            url: #{record.external_url}
        TEXT
      end

      display_results("Issues", fetch_issue_results(vector)) do |record, embedding|
        puts <<~TEXT
          - ##{record.external_id} (#{record.project_identifier})
            score: #{format('%.4f', embedding.neighbor_distance.to_f)}
            title: #{record.title.to_s.truncate(140)}
            status: #{record.status}
            url: #{record.external_url}
        TEXT
      end
    end
  end

  def embed_query(query)
    response = Llm::OllamaClient.embed_text(query)
    vectors = response.respond_to?(:vectors) ? response.vectors : response
    return if vectors.blank?

    vectors = vectors.first if vectors.is_a?(Array) && vectors.first.is_a?(Array)
    vectors
  rescue StandardError => e
    Rails.logger.error("[SearchRunner] Failed to embed query '#{query}': #{e.message}")
    nil
  end

  def fetch_commit_results(vector)
    Embedding.nearest_neighbors(:embedding, vector, distance: "cosine")
             .where(source_type: "GitlabCommit")
             .includes(:source)
             .limit(RESULT_LIMIT)
  end

  def fetch_wiki_results(vector)
    Embedding.nearest_neighbors(:embedding, vector, distance: "cosine")
             .where(source_type: "WikiPage")
             .includes(:source)
             .limit(RESULT_LIMIT)
  end

  def fetch_issue_results(vector)
    Embedding.nearest_neighbors(:embedding, vector, distance: "cosine")
             .where(source_type: "Issue")
             .includes(:source)
             .limit(RESULT_LIMIT)
  end

  def display_results(label, embeddings)
    puts "\n#{label}:"
    if embeddings.blank?
      puts "  (no results)"
      return
    end

    embeddings.each do |embedding|
      record = embedding.source
      next if record.nil?

      yield(record, embedding)
    end
  end
end

SearchRunner.run
