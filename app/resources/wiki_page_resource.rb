# frozen_string_literal: true

require "json"

class WikiPageResource < ApplicationResource
  uri "wiki/pages/{id}"
  resource_name "Wiki Page"
  description "Content for a cached Redmine wiki page"
  mime_type "application/json"

  def content
    JSON.pretty_generate(serialized_page)
  end

  private

  def serialized_page
    page = locate_page
    {
      id: page.id,
      external_id: page.external_id,
      project_identifier: page.project_identifier,
      title: page.title,
      slug: page.slug,
      summary: page.summary,
      content: page.content,
      updated_on: page.updated_on,
      external_url: page.external_url
    }.compact
  end

  def locate_page
    identifier = params.fetch(:id).to_s
    find_by_numeric_id(identifier) || find_by_external_id(identifier) || find_by_slug(identifier) || raise(FastMcp::Resource::NotFoundError, "Wiki page not found")
  end

  def find_by_numeric_id(identifier)
    return unless identifier.match?(/\A\d+\z/)

    WikiPage.find_by(id: identifier.to_i)
  end

  def find_by_external_id(identifier)
    WikiPage.find_by(external_id: identifier)
  end

  def find_by_slug(identifier)
    WikiPage.find_by(slug: identifier)
  end
end
