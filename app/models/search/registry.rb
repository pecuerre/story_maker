module Search
  # Every model that contributes documents to the index, in one list.
  #
  # This is an explicit registry rather than a reflection over `Searchable`
  # because the failure of a missing entry is silent: a model left out of the
  # reindex simply never appears in a search and nothing raises. `Ability` keeps
  # its class registry for the same reason, and the test that walks this list and
  # builds every document is what keeps it true.
  class Registry
    MODELS = [
      Universe,
      Story,
      Section,
      Scene,
      SceneElement,
      Character,
      Location,
      Item,
      Event,
      Relation,
      Ownership,
      CharacterTag,
      LocationTag,
      ItemTag,
      EventTag,
      RelationTag,
      OwnershipTag,
      SectionTag,
      SceneTag
    ].freeze

    # The models whose records are stored *below a scene*. Nothing is, except an
    # Element — a Scene has no children of its own. This is a list rather than a
    # reflection over `Searchable` for the reason above: a model left out is a
    # silent omission, because its documents keep the old scene's slug and nothing
    # anywhere reports that.
    SCENE_NESTED = [ SceneElement ].freeze

    class << self
      def models
        MODELS
      end

      # The relations holding one universe's searchable records, for a reindex of
      # that universe alone. Relations rather than records: the reindex reads them
      # in batches, and a universe large enough to matter should not be held in
      # memory to be indexed.
      #
      # How a model's records are reached is the model's own answer —
      # `Model.search_scope` — because only the model knows how deep it sits.
      def relations_for(universe)
        MODELS.reject { |model| model.search_declaration.self? }
          .map { |model| model.search_scope(universe) }
      end

      # One story's, for a reindex after a story's slug changed: every document
      # below it carries that slug in its stored path. Only the story-scoped models
      # are asked — a Character has no records under a story, so there is nothing
      # to repair and nothing to read.
      def relations_for_story(story)
        MODELS.select { |model| model.search_declaration.story? }
          .map { |model| model.search_scope_for_story(story) }
      end

      # One scene's, for a scene rename: only its Elements store the scene's slug.
      def relations_for_scene(scene)
        SCENE_NESTED.map { |model| model.search_scope_for_scene(scene) }
      end
    end
  end
end
