module StoryInterchange
  module Importers
    # One Event per Scene, written after the Scenes slice because it links each
    # Event back to the Scene that depicts it.
    #
    # The Event is named after its Scene. A `moment` with a concrete date or
    # clock time sets the Event's `start_datetime` (a date alone starts at
    # midnight). A relation sets the matching temporal reference instead:
    # `after <scene>` becomes `after_event`, `before <scene>` becomes
    # `before_event`, and `at the same time as <scene>` becomes
    # `simultaneous_event`. A span (`<N> <unit> after <scene>`) also computes the
    # Event's start from the target's own start when the target has one.
    #
    # The target is a scene path under `chapters/` without `.md`, so a relation
    # can point into another chapter. Relations may point forward, which is why
    # every Event is created before any relation is written.
    #
    # A relation states where its target is, not when the target is, so a chain
    # is resolved from the anchored end outward: every pass fills in the starts
    # a pass can now compute, and the passes repeat until one fills in nothing.
    # An Event keeps the start it was given and is never rewritten by a
    # relation, and a cycle of relations with no concrete date anywhere stays
    # relation-only rather than raising or inventing a date.
    class Events < Importer
      slice label_key: "imports.slices.events",
        count: :events,
        kind: :scene

      class << self
        # The preview lists the Event each Scene will create, named after that
        # Scene. Nothing is left behind: every accepted `moment` shape is either
        # a datetime or a temporal reference.
        def records(report)
          report.entities(:scene).map do |entity|
            Importer::Record.new(name: entity.name, slug: scene_slug(entity), notes: [])
          end
        end

        # The imported Scene's slug: the source filename without its `NN-`
        # sequence. `Scenes` writes the same value, and this slice must find the
        # same record rather than reading the file a second way.
        def scene_slug(entity)
          entity.scene_slug
        end

        # The key a `moment` relation names: the scene's path under its story's
        # `chapters/` directory, without `.md`.
        def scene_key(entity)
          [ entity.story_slug, "#{entity.chapter_slug}/#{entity.slug}" ]
        end
      end

      def call
        entities = report.entities(:scene)
        events = {}
        moments = {}

        # First every Event, so a relation may point forward to a scene that
        # appears later in reading order.
        created = entities.map do |entity|
          scene = scene_for(entity)
          moment = Moment.parse(entity.frontmatter["moment"])
          event = Event.create!(
            universe: universe,
            title: scene.name,
            start_datetime: moment.datetime
          )
          SceneEvent.create!(scene: scene, event: event)
          key = self.class.scene_key(entity)
          events[key] = event
          moments[key] = moment
          event
        end

        resolve_moments(entities, events, moments)

        Outcome.new(label_key: label_key, created: created.size, records: self.class.records(report))
      end

      private
        def scene_for(entity)
          universe.stories.find_by!(slug: entity.story_slug)
            .scenes.find_by!(slug: self.class.scene_slug(entity))
        end

        # Relations are written once, then the dates they imply are filled
        # until a whole pass adds none. A pass exists because a relation names
        # its target, not its target's date: a chain anchored at the far end is
        # only computable from the anchor outward, whatever order the Scenes
        # appear in.
        def resolve_moments(entities, events, moments)
          relations = entities.map do |entity|
            key = self.class.scene_key(entity)
            moment = moments.fetch(key)
            event = events.fetch(key)
            target = events[[ entity.story_slug, moment.reference ]] if moment.relation?
            [ moment, event, target ]
          end

          relations.each do |moment, event, target|
            next if target.nil?

            if moment.simultaneous?
              event.update!(simultaneous_event: target)
            else
              link_reference(event, moment.direction, target)
            end
          end

          changed = true
          while changed
            changed = false
            relations.each do |moment, event, target|
              next if target.nil? || event.start_datetime.present?

              start_datetime = computed_start(moment, target)
              next if start_datetime.nil?

              event.update!(start_datetime: start_datetime)
              changed = true
            end
          end
        end

        # The instant a relation supplies, or nil when it supplies none. A bare
        # direction says only which way round two Events are; a span states a
        # distance, so it is subtracted for `before` and added for `after`; a
        # simultaneity is the target's own instant.
        def computed_start(moment, target)
          return if target.start_datetime.blank?

          return target.start_datetime if moment.simultaneous?
          return unless moment.span?

          amount = moment.direction == "before" ? -moment.amount : moment.amount
          target.start_datetime.advance(moment.unit => amount)
        end

        def link_reference(event, direction, target)
          if direction == "before"
            event.update!(before_event: target)
          else
            event.update!(after_event: target)
          end
        end
    end
  end
end
