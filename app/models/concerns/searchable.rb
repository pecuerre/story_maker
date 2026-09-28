# Makes a model searchable by describing, in the model, what is worth finding and
# how the record is reached.
#
#   class Character < ApplicationRecord
#     include Searchable
#     searchable kind: "character", title: :name, body: :description, route: "character"
#   end
#
# Each declaration produces one document in the shared index. The `kind` is the
# only thing a scope filters on, `title`/`body` are the only fields the engine
# searches, and `route` is the nested route segment the record lives at, which
# keeps search's routing knowledge next to the record instead of in a central
# table that can drift from the routes.
#
# Two decisions are deliberate and would be expensive to reverse:
#
# * A document stores `universe_id` and `story_id`, never the universe's or
#   story's *name*. Renaming either then needs no reindex of the records that
#   mention it, and `Search::Catalog` resolves the displayed context at read
#   time, so a stale index cannot show an old name.
# * A document stores its own `url`. Search results are rendered as links, and
#   making the engine return a bare id would push route knowledge into every
#   view. Slugs are assigned once, when a record is created, so a stored path
#   stays valid; `bin/rails search:reindex` is the answer for anything else.
#
# Writes are queued, not performed. A save must not block on — or fail because of
# — a search service, and the document is built at commit time so the job never
# needs the record to still exist.
module Searchable
  extend ActiveSupport::Concern

  # The index's primary key, and the one thing that must never collide.
  #
  # It is built from the *model*, not from the kind, because a kind is not a
  # model: the eight taxonomies all search as `tag`, so a kind-based id would
  # have Character Tag 1 and Location Tag 1 overwrite one another and a universe
  # would quietly lose seven eighths of its tags. The kind is what a scope
  # filters on; the id only has to be unique and addressable.
  #
  # The separator is a hyphen and the name is underscored because Meilisearch
  # accepts only alphanumerics, hyphens, and underscores in a document id, and
  # refuses a whole batch over one bad id. `test/models/searchable_test.rb` holds
  # every declared model to that rule, because a rejected document fails silently
  # everywhere except the engine's own task log.
  ID_SEPARATOR = "-"
  # How a document finds its Universe, and how it finds its own page:
  #
  #   :universe  a universe record: `universe_id`, and a page nested under `/u/`
  #   :story     a story record: its own Story's universe, and a page nested
  #              under the story. The document keeps both ids so a
  #              platform-wide filter can reach it.
  #   :self      the record *is* its own boundary — only the Universe, which is
  #              reached by `universe_path` rather than a nested route and is
  #              filtered by its own id.
  SCOPES = %i[ universe story self ].freeze

  # A declaration is a model's own answer to three questions: what kind of record
  # this is, which of its fields answer a search, and where the record lives.
  class Declaration
    attr_reader :kind, :title, :body, :route, :scope, :taxonomy

    def initialize(kind:, title:, body: nil, route: nil, scope: :universe, taxonomy: nil)
      raise ArgumentError, "kind is required" if kind.blank?
      raise ArgumentError, "unknown scope #{scope.inspect}" unless SCOPES.include?(scope)

      @kind = kind.to_s
      @title = title
      @body = body
      # `route` is optional only for a model that defines its own `search_url`,
      # which is what a record whose page belongs to its owner does.
      @route = route&.to_s
      @scope = scope
      @taxonomy = taxonomy&.to_s
    end

    def story?
      scope == :story
    end

    def self?
      scope == :self
    end

    # Fails loudly rather than building `universe__path` for a declaration that
    # has neither a route nor its own `search_url`.
    def route!
      return route if route.present?

      raise ArgumentError,
        "the #{kind} declaration names no route, so it must define its own search_url"
    end
  end

  included do
    # An update re-indexes the record; a destroy removes it. `after_commit`
    # means an index write never happens for a transaction that rolls back.
    after_commit :queue_search_index_update, on: %i[ create update ]
    after_destroy_commit :queue_search_removal
  end

  class_methods do
    # Declares what this model contributes to the index. One call per model, and
    # the only place that model's searchable fields are named.
    def searchable(kind:, title:, body: nil, route: nil, scope: :universe, taxonomy: nil)
      @search_declaration = Declaration.new(kind:, title:, body:, route:, scope:, taxonomy:)
    end

    def search_declaration
      @search_declaration
    end

    def searchable?
      @search_declaration.present?
    end

    # The records of one universe that a reindex of that universe must write.
    # A model declares it because only the model knows how deep it sits: a Scene
    # Element is story-scoped through its Scene and has no `story_id` of its own.
    def search_scope(universe)
      declaration = search_declaration
      return where(id: universe.id) if declaration.self?
      return where(universe_id: universe.id) unless declaration.story?

      if column_names.include?("story_id")
        where(story_id: universe.stories.select(:id))
      else
        raise NotImplementedError,
          "#{name} is story-scoped but stores no story_id, so it must declare its own search_scope"
      end
    end
  end

  # The index's primary key. See `ID_SEPARATOR` for why this names the model and
  # not the kind.
  def search_id
    [ self.class.name.demodulize.underscore, id ].join(ID_SEPARATOR)
  end

  def search_document
    declaration = self.class.search_declaration

    {
      id: search_id,
      kind: declaration.kind,
      taxonomy: declaration.taxonomy,
      universe_id: search_universe_id,
      story_id: search_story_id,
      title: search_text(declaration.title),
      body: search_text(declaration.body),
      url: search_url,
      updated_at: updated_at&.to_i
    }
  end

  private
    # Both callbacks are internal to this concern: the only way a model becomes
    # searchable is by declaring it. The document is built here, at commit time,
    # because the job must write the state that was committed and the record may
    # be edited again — or deleted — before the job runs.
    def queue_search_index_update
      # A soft delete is an update that hides the record, so the document must
      # leave the index rather than be re-indexed. A restore re-indexes it.
      if respond_to?(:deleted?) && deleted?
        queue_search_removal
      else
        Search::IndexRecordJob.perform_later(search_document)
      end
    end

    def queue_search_removal
      Search::RemoveRecordJob.perform_later(search_id)
    end

    def search_text(attribute)
      return nil if attribute.nil?

      public_send(attribute).to_s.squish.presence
    end

    def search_universe_id
      declaration = self.class.search_declaration
      return id if declaration.self?
      return story&.universe_id if declaration.story?

      universe_id
    end

    # A story-scoped record normally stores its own `story_id`. A Scene Element is
    # the exception — it is two joins from its story — so it reads the association
    # rather than carrying a column that would be a second source of truth.
    def search_story_id
      return nil unless self.class.search_declaration.story?

      respond_to?(:story_id) ? story_id : story&.id
    end

    # Both nested scopes end in the record's own id, so the two shapes only
    # differ in the keys they need.
    def search_url
      declaration = self.class.search_declaration
      routes = Rails.application.routes.url_helpers

      if declaration.self?
        # `universe_path` is the one top-level route a record can be reached by,
        # and it takes the record so `to_param` supplies the slug.
        routes.universe_path(self)
      elsif declaration.story?
        routes.public_send(:"universe_story_#{declaration.route!}_path",
          universe_slug: story.universe.to_param, story_id: story_id, id: id)
      else
        routes.public_send(:"universe_#{declaration.route!}_path",
          universe_slug: universe.to_param, id: id)
      end
    end
end
