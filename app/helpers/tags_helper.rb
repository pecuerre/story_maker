module TagsHelper
  UNIVERSE_TAG_TYPES = %w[character relation location event item ownership].freeze
  STORY_TAG_TYPES = %w[section scene].freeze

  TAG_LABELS = {
    "character" => "Character tags",
    "relation" => "Relation tags",
    "location" => "Location tags",
    "event" => "Event tags",
    "item" => "Item tags",
    "ownership" => "Ownership tags",
    "section" => "Section tags",
    "scene" => "Scene tags"
  }.freeze

  # The per-type workspace copy for the universe taxonomies. The mechanical
  # keys — `model_param`, the field-descriptor helper, the tag URLs, and the
  # count label — are derived from the type name, so adding a taxonomy means
  # adding one entry here rather than a second hand-maintained block that can
  # drift from the routes and from `modal_fields.rb`.
  UNIVERSE_TAG_METADATA = {
    "character" => {
      title: "Character tags",
      description: "Define the optional labels used to organize characters across this universe.",
      empty_description: "Tags are optional. Add one to group characters, or create characters without a tag.",
      read_only_empty_description: "No character tags are defined yet.",
      new_label: "Add character tag"
    },
    "relation" => {
      title: "Relation tags",
      description: "Define the relationship types used when connecting characters in this universe.",
      empty_description: "Tags are optional. Add one to describe character relationships, or leave relations untagged.",
      read_only_empty_description: "No relation tags are defined yet.",
      new_label: "Add relation tag"
    },
    "location" => {
      title: "Location tags",
      description: "Organize the places and regions that make up this universe.",
      empty_description: "Tags are optional. Add one to group locations, or organize them later.",
      read_only_empty_description: "No location tags are defined yet.",
      new_label: "Add location tag"
    },
    "event" => {
      title: "Event tags",
      description: "Classify events so related moments are easier to find across the timeline.",
      empty_description: "Tags are optional. Add one to group events, or rely on dates and relationships instead.",
      read_only_empty_description: "No event tags are defined yet.",
      new_label: "Add event tag"
    },
    "item" => {
      title: "Item tags",
      description: "Define optional categories for objects and resources in this universe.",
      empty_description: "Tags are optional. Add one to group items, or create untagged items.",
      read_only_empty_description: "No item tags are defined yet.",
      new_label: "Add item tag"
    },
    "ownership" => {
      title: "Ownership tags",
      description: "Describe the kinds of ownership recorded between characters and items.",
      empty_description: "Tags are optional. Add one to classify ownership records, or create them untagged.",
      read_only_empty_description: "No ownership tags are defined yet.",
      new_label: "Add ownership tag"
    }
  }.freeze

  STORY_TAG_METADATA = {
    "section" => {
      title: "Section tags",
      description: "Define labels such as book, chapter, act, or episode for this story's sections.",
      empty_description: "Tags are optional. Add one to classify sections, or build the section tree without them.",
      read_only_empty_description: "This story has no section tags defined yet.",
      new_label: "Add section tag"
    },
    "scene" => {
      title: "Scene tags",
      description: "Define optional labels for this story's scenes, such as mood, turning point, or story beat.",
      empty_description: "Tags are optional. Add one to classify scenes, or write scenes without a tag.",
      read_only_empty_description: "This story has no scene tags defined yet.",
      new_label: "Add scene tag",
      confirm_message: ->(tag) {
        "Delete “#{tag.name}”? Its child tags and assignments will be removed. Scenes will remain."
      }
    }
  }.freeze

  def tag_workspace_navigation_data(scope:, taxonomy:)
    scope = scope.to_s == "story" ? "story" : "universe"
    taxonomy = normalized_tag_workspace_type(scope, taxonomy)
    universe_taxonomy = scope == "story" ? "character" : taxonomy
    taxonomy_tabs = if scope == "story"
      STORY_TAG_TYPES.map do |type|
        {
          label: TAG_LABELS.fetch(type),
          path: universe_tags_path(scope: "story", taxonomy: type),
          controller: :tags,
          active: taxonomy == type
        }
      end
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
          path: universe_tags_path(scope: "story", taxonomy: taxonomy),
          controller: :tags,
          active: scope == "story"
        }
      ],
      taxonomy_tabs: taxonomy_tabs
    }
  end

  def tag_workspace_config(scope:, taxonomy:)
    return story_tag_workspace_config(normalized_tag_workspace_type("story", taxonomy)) if scope.to_s == "story"

    universe_tag_workspace_config(normalized_tag_workspace_type("universe", taxonomy))
  end

  def tag_workspace_default_scope
    %w[section_tags scene_tags].include?(controller_name) ? "story" : "universe"
  end

  def tag_workspace_default_taxonomy
    return controller_name.delete_suffix("_tags") if %w[section_tags scene_tags].include?(controller_name)
    return "character" if controller_name == "tags"

    controller_name.to_s.delete_suffix("_tags")
  end

  # How many records carry each tag, from one grouped query. See
  # `TaggedRecordCounts`: the scoped HABTM sides cannot be eager loaded, so this
  # exists to keep a taxonomy row's "(10 characters)" count out of an N+1.
  def tagged_record_counts(records)
    TaggedRecordCounts.for(records)
  end

  # The tags each record carries, from one grouped query, for a tag details
  # page's record list. See `RecordTags`: the same eager-loading limit means
  # the per-row badge list is read once for the whole page, not once per row.
  def record_tags_for(records)
    RecordTags.for(records)
  end

  # Tabs for a content workspace. Tag links explicitly carry their origin so
  # the tag details page can preserve this navigation without relying on a
  # potentially absent or untrusted Referer header.
  def content_workspace_tabs(type, active_tag: nil)
    type = type.to_s
    base_tabs = case type
    when "character"
      [
        { label: "Characters", path: universe_characters_path, controller: :characters },
        { label: "Relations", path: universe_relations_path, controller: :relations }
      ]
    when "location"
      [ { label: "Locations", path: universe_locations_path, controller: :locations } ]
    when "event"
      [ { label: "Events", path: universe_events_path, controller: :events } ]
    when "item"
      [
        { label: "Items", path: universe_items_path, controller: :items },
        { label: "Ownerships", path: universe_ownerships_path, controller: :ownerships }
      ]
    else
      return []
    end

    base_tabs.each do |tab|
      tab[:active] = active_tag.nil? && controller.controller_name == tab.fetch(:controller).to_s
    end

    menu_tags = Current.universe.public_send(:"#{type}_tags").where(show_in_menu: true).order(:position, :id)
    tag_tabs = menu_tags.map do |tag|
      {
        label: tag.name,
        path: public_send(:"universe_#{type}_tag_path", id: tag, from: "workspace"),
        controller: :"#{type}_tags",
        active: active_tag&.id == tag.id
      }
    end

    base_tabs + tag_tabs
  end

  private
    def normalized_tag_workspace_type(scope, taxonomy)
      if scope.to_s == "story"
        return "section" unless STORY_TAG_TYPES.include?(taxonomy.to_s)

        return taxonomy.to_s
      end

      return "character" unless UNIVERSE_TAG_TYPES.include?(taxonomy.to_s)

      taxonomy.to_s
    end

    def universe_tag_workspace_config(type)
      metadata = UNIVERSE_TAG_METADATA.fetch(type)
      records = Current.universe.public_send(:"#{type}_tags")

      tag_workspace_base(records, metadata.merge(
        model_param: "#{type}_tag",
        fields: :"#{type}_tag_taxonomy_fields",
        create_url: public_send(:"universe_#{type}_tags_path"),
        update_url: ->(tag) { public_send(:"universe_#{type}_tag_path", id: tag) },
        details_url: ->(tag) { public_send(:"universe_#{type}_tag_path", id: tag) },
        details_count_label: type
      ))
    end

    def story_tag_workspace_config(type)
      story = Current.story
      return if story.nil?

      metadata = STORY_TAG_METADATA.fetch(type)
      records = story.public_send(:"#{type}_tags")

      tag_workspace_base(records, metadata.merge(
        model_param: "#{type}_tag",
        fields: :"#{type}_tag_taxonomy_fields",
        create_url: public_send(:"universe_story_#{type}_tags_path", story_id: story),
        update_url: ->(tag) { public_send(:"universe_story_#{type}_tag_path", story_id: story, id: tag) },
        details_url: ->(tag) { public_send(:"universe_story_#{type}_tag_path", story_id: story, id: tag) },
        details_count_label: type
      ))
    end

    def tag_workspace_base(records, metadata)
      ordered_records = records.order(:position, :id).to_a
      nodes = records.where(parent_id: nil).includes(:children).order(:position, :id)
      counts = tagged_record_counts(records)

      metadata.merge(
        count: ordered_records.length,
        nodes: nodes,
        details_url: metadata.fetch(:details_url),
        details_count: ->(tag) { counts.fetch(tag.id, 0) },
        details_count_label: metadata.fetch(:details_count_label),
        modal_fields: public_send(metadata.fetch(:fields), ordered_records)
      )
    end
end
