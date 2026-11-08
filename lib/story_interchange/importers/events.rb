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

        # The imported Scene's slug. `Scenes` builds it from the chapter
        # directory and the scene filename, and this slice must find the same
        # record rather than reading the file a second way.
        def scene_slug(entity)
          "#{entity.chapter_slug}-#{entity.slug}"
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
          events[self.class.scene_key(entity)] = event
          event
        end

        entities.each do |entity|
          moment = Moment.parse(entity.frontmatter["moment"])
          apply_moment(events.fetch(self.class.scene_key(entity)), moment, events, entity)
        end

        Outcome.new(label_key: label_key, created: created.size, records: self.class.records(report))
      end

      private
        def scene_for(entity)
          universe.stories.find_by!(slug: entity.story_slug)
            .scenes.find_by!(slug: self.class.scene_slug(entity))
        end

        def apply_moment(event, moment, events, entity)
          return unless moment.relation?

          target = events[[ entity.story_slug, moment.reference ]]
          return if target.nil?

          if moment.simultaneous?
            event.update!(simultaneous_event: target)
            # The target's date, when it has one, is the same instant for this
            # Event too. A relation-only target leaves this one relation-only.
            event.update!(start_datetime: target.start_datetime) if
              event.start_datetime.blank? && target.start_datetime.present?
            return
          end

          link_reference(event, moment.direction, target)

          return unless moment.span? && event.start_datetime.blank? && target.start_datetime.present?

          event.update!(start_datetime: target.start_datetime.advance(moment.unit => moment.amount))
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
