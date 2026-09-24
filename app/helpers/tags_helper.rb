module TagsHelper
  UNIVERSE_TAG_TYPES = %w[character relation location event item ownership].freeze

  TAG_LABELS = {
    "character" => "Character tags",
    "relation" => "Relation tags",
    "location" => "Location tags",
    "event" => "Event tags",
    "item" => "Item tags",
    "ownership" => "Ownership tags",
    "section" => "Section tags"
  }.freeze

  def tag_workspace_navigation_data(scope:, taxonomy:)
    scope = scope.to_s == "story" ? "story" : "universe"
    taxonomy = normalized_tag_workspace_type(scope, taxonomy)
    universe_taxonomy = scope == "story" ? "character" : taxonomy
    taxonomy_tabs = if scope == "story"
      [
        {
          label: TAG_LABELS.fetch("section"),
          path: universe_tags_path(scope: "story", taxonomy: "section"),
          controller: :tags,
          active: taxonomy == "section"
        }
      ]
    else
      UNIVERSE_TAG_TYPES.map do |type|
        {
          label: TAG_LABELS.fetch(type),
          path: universe_tags_path(scope: "universe", taxonomy: type),
          controller: :tags,
          active: taxonomy == type
        }
      end
    end

    {
      scope_tabs: [
        {
          label: "Universe Tags",
          path: universe_tags_path(scope: "universe", taxonomy: universe_taxonomy),
          controller: :tags,
          active: scope == "universe"
        },
        {
          label: "Story Tags",
          path: universe_tags_path(scope: "story", taxonomy: "section"),
          controller: :tags,
          active: scope == "story"
        }
      ],
      taxonomy_tabs: taxonomy_tabs
    }
  end

  def tag_workspace_config(scope:, taxonomy:)
    return story_tag_workspace_config if scope.to_s == "story"

    universe_tag_workspace_config(normalized_tag_workspace_type("universe", taxonomy))
  end

  def tag_workspace_default_scope
    controller_name == "section_tags" ? "story" : "universe"
  end

  def tag_workspace_default_taxonomy
    return "section" if controller_name == "section_tags"
    return "character" if controller_name == "tags"

    controller_name.to_s.delete_suffix("_tags")
  end

  private
    def normalized_tag_workspace_type(scope, taxonomy)
      return "section" if scope.to_s == "story"
      return "character" unless UNIVERSE_TAG_TYPES.include?(taxonomy.to_s)

      taxonomy.to_s
    end

    def universe_tag_workspace_config(type)
      metadata = case type
      when "character"
        {
          title: TAG_LABELS.fetch("character"),
          description: "Define the optional labels used to organize characters across this universe.",
          empty_description: "Tags are optional. Add one to group characters, or create characters without a tag.",
          new_label: "Add character tag",
          model_param: "character_tag",
          fields: :character_tag_taxonomy_fields,
          new_url: ->(parent = nil) { new_universe_character_tag_path(parent_id: parent&.id) },
          create_url: universe_character_tags_path,
          edit_url: ->(tag) { edit_universe_character_tag_path(id: tag) },
          update_url: ->(tag) { universe_character_tag_path(id: tag) },
          delete_url: ->(tag) { universe_character_tag_path(id: tag) }
        }
      when "relation"
        {
          title: TAG_LABELS.fetch("relation"),
          description: "Define the relationship types used when connecting characters in this universe.",
          empty_description: "Tags are optional. Add one to describe character relationships, or leave relations untagged.",
          new_label: "Add relation tag",
          model_param: "relation_tag",
          fields: :relation_tag_taxonomy_fields,
          new_url: ->(parent = nil) { new_universe_relation_tag_path(parent_id: parent&.id) },
          create_url: universe_relation_tags_path,
          edit_url: ->(tag) { edit_universe_relation_tag_path(id: tag) },
          update_url: ->(tag) { universe_relation_tag_path(id: tag) },
          delete_url: ->(tag) { universe_relation_tag_path(id: tag) }
        }
      when "location"
        {
          title: TAG_LABELS.fetch("location"),
          description: "Organize the places and regions that make up this universe.",
          empty_description: "Tags are optional. Add one to group locations, or organize them later.",
          new_label: "Add location tag",
          model_param: "location_tag",
          fields: :location_tag_taxonomy_fields,
          new_url: ->(parent = nil) { new_universe_location_tag_path(parent_id: parent&.id) },
          create_url: universe_location_tags_path,
          edit_url: ->(tag) { edit_universe_location_tag_path(id: tag) },
          update_url: ->(tag) { universe_location_tag_path(id: tag) },
          delete_url: ->(tag) { universe_location_tag_path(id: tag) }
        }
      when "event"
        {
          title: TAG_LABELS.fetch("event"),
          description: "Classify events so related moments are easier to find across the timeline.",
          empty_description: "Tags are optional. Add one to group events, or rely on dates and relationships instead.",
          new_label: "Add event tag",
          model_param: "event_tag",
          fields: :event_tag_taxonomy_fields,
          new_url: ->(parent = nil) { new_universe_event_tag_path(parent_id: parent&.id) },
          create_url: universe_event_tags_path,
          edit_url: ->(tag) { edit_universe_event_tag_path(id: tag) },
          update_url: ->(tag) { universe_event_tag_path(id: tag) },
          delete_url: ->(tag) { universe_event_tag_path(id: tag) }
        }
      when "item"
        {
          title: TAG_LABELS.fetch("item"),
          description: "Define optional categories for objects and resources in this universe.",
          empty_description: "Tags are optional. Add one to group items, or create untagged items.",
          new_label: "Add item tag",
          model_param: "item_tag",
          fields: :item_tag_taxonomy_fields,
          new_url: ->(parent = nil) { new_universe_item_tag_path(parent_id: parent&.id) },
          create_url: universe_item_tags_path,
          edit_url: ->(tag) { edit_universe_item_tag_path(id: tag) },
          update_url: ->(tag) { universe_item_tag_path(id: tag) },
          delete_url: ->(tag) { universe_item_tag_path(id: tag) }
        }
      when "ownership"
        {
          title: TAG_LABELS.fetch("ownership"),
          description: "Describe the kinds of ownership recorded between characters and items.",
          empty_description: "Tags are optional. Add one to classify ownership records, or create them untagged.",
          new_label: "Add ownership tag",
          model_param: "ownership_tag",
          fields: :ownership_tag_taxonomy_fields,
          new_url: ->(parent = nil) { new_universe_ownership_tag_path(parent_id: parent&.id) },
          create_url: universe_ownership_tags_path,
          edit_url: ->(tag) { edit_universe_ownership_tag_path(id: tag) },
          update_url: ->(tag) { universe_ownership_tag_path(id: tag) },
          delete_url: ->(tag) { universe_ownership_tag_path(id: tag) }
        }
      end

      tag_workspace_base(Current.universe.public_send(:"#{type}_tags"), metadata)
    end

    def story_tag_workspace_config
      story = Current.story
      return if story.nil?

      tag_workspace_base(story.section_tags, {
        title: TAG_LABELS.fetch("section"),
        description: "Define labels such as book, chapter, act, or episode for this story's sections.",
        empty_description: "Tags are optional. Add one to classify sections, or build the section tree without them.",
        new_label: "Add section tag",
        model_param: "section_tag",
        fields: :section_tag_taxonomy_fields,
        new_url: ->(parent = nil) { new_universe_story_section_tag_path(story_id: story, parent_id: parent&.id) },
        create_url: universe_story_section_tags_path(story_id: story),
        edit_url: ->(tag) { edit_universe_story_section_tag_path(story_id: story, id: tag) },
        update_url: ->(tag) { universe_story_section_tag_path(story_id: story, id: tag) },
        delete_url: ->(tag) { universe_story_section_tag_path(story_id: story, id: tag) }
      })
    end

    def tag_workspace_base(records, metadata)
      ordered_records = records.order(:position, :id).to_a
      nodes = records.where(parent_id: nil).includes(:children).order(:position, :id)

      metadata.merge(
        count: ordered_records.length,
        nodes: nodes,
        modal_fields: public_send(metadata.fetch(:fields), ordered_records)
      )
    end
end
