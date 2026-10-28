# A small, curated set of story shapes a writer can apply to an empty Story.
#
# The catalogue is code-owned, like `TropeCatalog`: adding or changing a
# structure is a code change, and no Universe or Story owns a template row. An
# entry names its acts and beats through I18n keys rather than translated
# strings, so the catalogue can be read in the request's language. Applying one
# creates ordinary Sections and Scenes, and never a template record or any
# Element prose.
class StoryStructureCatalog
  Beat = Data.define(:name_key, :description_key)
  Act = Data.define(:name_key, :beats)

  Entry = Data.define(:slug, :name_key, :description_key, :acts) do
    def section_count
      acts.size
    end

    def scene_count
      acts.sum { |act| act.beats.size }
    end
  end

  ENTRIES = [
    Entry.new(
      slug: "three-act",
      name_key: "stories.structures.catalog.three_act.name",
      description_key: "stories.structures.catalog.three_act.description",
      acts: [
        Act.new(
          name_key: "stories.structures.catalog.three_act.acts.setup.name",
          beats: [
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.setup.beats.opening_image.name",
              description_key: "stories.structures.catalog.three_act.acts.setup.beats.opening_image.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.setup.beats.inciting_incident.name",
              description_key: "stories.structures.catalog.three_act.acts.setup.beats.inciting_incident.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.setup.beats.first_plot_point.name",
              description_key: "stories.structures.catalog.three_act.acts.setup.beats.first_plot_point.description"
            )
          ]
        ),
        Act.new(
          name_key: "stories.structures.catalog.three_act.acts.confrontation.name",
          beats: [
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.confrontation.beats.rising_action.name",
              description_key: "stories.structures.catalog.three_act.acts.confrontation.beats.rising_action.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.confrontation.beats.midpoint.name",
              description_key: "stories.structures.catalog.three_act.acts.confrontation.beats.midpoint.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.confrontation.beats.second_plot_point.name",
              description_key: "stories.structures.catalog.three_act.acts.confrontation.beats.second_plot_point.description"
            )
          ]
        ),
        Act.new(
          name_key: "stories.structures.catalog.three_act.acts.resolution.name",
          beats: [
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.resolution.beats.climax.name",
              description_key: "stories.structures.catalog.three_act.acts.resolution.beats.climax.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.three_act.acts.resolution.beats.resolution.name",
              description_key: "stories.structures.catalog.three_act.acts.resolution.beats.resolution.description"
            )
          ]
        )
      ]
    ),
    Entry.new(
      slug: "heros-journey",
      name_key: "stories.structures.catalog.heros_journey.name",
      description_key: "stories.structures.catalog.heros_journey.description",
      acts: [
        Act.new(
          name_key: "stories.structures.catalog.heros_journey.acts.departure.name",
          beats: [
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.departure.beats.ordinary_world.name",
              description_key: "stories.structures.catalog.heros_journey.acts.departure.beats.ordinary_world.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.departure.beats.call_to_adventure.name",
              description_key: "stories.structures.catalog.heros_journey.acts.departure.beats.call_to_adventure.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.departure.beats.refusal_of_the_call.name",
              description_key: "stories.structures.catalog.heros_journey.acts.departure.beats.refusal_of_the_call.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.departure.beats.meeting_the_mentor.name",
              description_key: "stories.structures.catalog.heros_journey.acts.departure.beats.meeting_the_mentor.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.departure.beats.crossing_the_threshold.name",
              description_key: "stories.structures.catalog.heros_journey.acts.departure.beats.crossing_the_threshold.description"
            )
          ]
        ),
        Act.new(
          name_key: "stories.structures.catalog.heros_journey.acts.initiation.name",
          beats: [
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.tests_allies_enemies.name",
              description_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.tests_allies_enemies.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.approach_inmost_cave.name",
              description_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.approach_inmost_cave.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.ordeal.name",
              description_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.ordeal.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.reward.name",
              description_key: "stories.structures.catalog.heros_journey.acts.initiation.beats.reward.description"
            )
          ]
        ),
        Act.new(
          name_key: "stories.structures.catalog.heros_journey.acts.return.name",
          beats: [
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.return.beats.road_back.name",
              description_key: "stories.structures.catalog.heros_journey.acts.return.beats.road_back.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.return.beats.resurrection.name",
              description_key: "stories.structures.catalog.heros_journey.acts.return.beats.resurrection.description"
            ),
            Beat.new(
              name_key: "stories.structures.catalog.heros_journey.acts.return.beats.return_with_the_elixir.name",
              description_key: "stories.structures.catalog.heros_journey.acts.return.beats.return_with_the_elixir.description"
            )
          ]
        )
      ]
    )
  ].freeze

  class << self
    def entries
      ENTRIES
    end

    def slugs
      @slugs ||= ENTRIES.map(&:slug).freeze
    end

    def find(slug)
      ENTRIES.find { |entry| entry.slug == slug.to_s }
    end
  end
end
