module StoryInterchange
  module Importers
    # A Location is its frontmatter plus the profile answers the source's `##`
    # sections map to. `Sensory`, `Layout`, `Control and access`, and `History`
    # each fill several answers: a labelled list item writes every answer its
    # label names, and text whose label names none — or prose with no label at all
    # — fills the group's first answer.
    #
    # `type`, `controller`, `status`, and `backlog` have no Location column, so
    # they are reported along with the sections the app does not keep (Who is
    # here, Events here, Story rules affecting this place, Open questions).
    #
    # The source is a flat directory and a Location carries a `parent_id`, but a
    # filename says nothing about the hierarchy, so every imported Location is
    # top-level and the operator builds the tree in the app.
    class Locations < Importer
      slice label_key: "imports.slices.locations",
        count: :locations,
        kind: :location,
        profile: {
          "what it is" => :description,
          "sensory" => {
            "sight" => :sensory_sight,
            "sound" => :sensory_sound,
            "smell" => :sensory_smell,
            "taste" => :sensory_taste,
            "touch" => :sensory_touch
          },
          "layout" => {
            "structure" => :layout_structure,
            "key areas" => :layout_key_areas,
            "pathways" => :layout_pathways,
            "entrances" => :layout_entrances_exits,
            "points of interest" => :layout_points_of_interest
          },
          "why it matters" => :significance,
          "control and access" => {
            "controlled by" => :access_controlled_by,
            "operated by" => :access_controlled_by,
            "granted" => :access_granted_how,
            "security" => :access_security,
            "restricted" => :access_restrictions,
            "cannot leave" => :access_restrictions
          },
          "history" => {
            "significant events" => :history_significant_events,
            "past occupants" => :history_past_occupants,
            "changes" => :history_changes
          }
        },
        reported_keys: %w[type controller status backlog]

      def call
        write_entities(Location)
      end
    end
  end
end
