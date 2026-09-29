module TagsHelper
  UNIVERSE_TAG_TYPES = %w[character relation location event item ownership].freeze
  STORY_TAG_TYPES = %w[section scene].freeze

  # The tab label for each taxonomy. The label is a property of the taxonomy
  # rather than of a page, so it is read from the per-type locale block the
  # workspace copy below already uses rather than kept in a second hand-written
  # list that could drift from the routes.
  def tag_type_label(type)
    t("tags.types.#{type}.title")
  end

  # The per-type workspace copy for the universe taxonomies, held as I18n keys
  # and translated when the workspace is read. The mechanical keys —
  # `model_param`, the field-descriptor helper, the tag URLs, and the count
  # label — are derived from the type name, so adding a taxonomy means adding
  # one entry here plus its locale block rather than a second hand-maintained
  # block that can drift from the routes and from `modal_fields.rb`.
  #
  # The values are *keys*, not copy: a constant holding translated strings would
  # be built once, in whatever locale loaded the class first, and every later
  # request would render that one language. `tag_workspace_base` resolves them.
  UNIVERSE_TAG_METADATA = {
    "character" => {
      title_key: "tags.types.character.title",
      description_key: "tags.types.character.description",
      empty_description_key: "tags.types.character.empty_description",
      read_only_empty_description_key: "tags.types.character.read_only_empty_description",
      new_label_key: "tags.types.character.new_label"
    },
    "relation" => {
      title_key: "tags.types.relation.title",
      description_key: "tags.types.relation.description",
      empty_description_key: "tags.types.relation.empty_description",
      read_only_empty_description_key: "tags.types.relation.read_only_empty_description",
      new_label_key: "tags.types.relation.new_label"
    },
    "location" => {
      title_key: "tags.types.location.title",
      description_key: "tags.types.location.description",
      empty_description_key: "tags.types.location.empty_description",
      read_only_empty_description_key: "tags.types.location.read_only_empty_description",
      new_label_key: "tags.types.location.new_label"
    },
    "event" => {
      title_key: "tags.types.event.title",
      description_key: "tags.types.event.description",
      empty_description_key: "tags.types.event.empty_description",
      read_only_empty_description_key: "tags.types.event.read_only_empty_description",
      new_label_key: "tags.types.event.new_label"
    },
    "item" => {
      title_key: "tags.types.item.title",
      description_key: "tags.types.item.description",
      empty_description_key: "tags.types.item.empty_description",
      read_only_empty_description_key: "tags.types.item.read_only_empty_description",
      new_label_key: "tags.types.item.new_label"
    },
    "ownership" => {
      title_key: "tags.types.ownership.title",
      description_key: "tags.types.ownership.description",
      empty_description_key: "tags.types.ownership.empty_description",
      read_only_empty_description_key: "tags.types.ownership.read_only_empty_description",
      new_label_key: "tags.types.ownership.new_label"
    }
  }.freeze

  # The per-type copy for this story's section and scene taxonomies.
  STORY_TAG_METADATA = {
    "section" => {
      title_key: "tags.types.section.title",
      description_key: "tags.types.section.description",
      empty_description_key: "tags.types.section.empty_description",
      read_only_empty_description_key: "tags.types.section.read_only_empty_description",
      new_label_key: "tags.types.section.new_label"
    },
    "scene" => {
      title_key: "tags.types.scene.title",
      description_key: "tags.types.scene.description",
      empty_description_key: "tags.types.scene.empty_description",
      read_only_empty_description_key: "tags.types.scene.read_only_empty_description",
      new_label_key: "tags.types.scene.new_label",
      confirm_message_key: "tags.types.scene.delete_confirm"
    }
  }.freeze

  def tag_workspace_navigation_data(scope:, taxonomy:)
    scope = scope.to_s == "story" ? "story" : "universe"
    taxonomy = normalized_tag_workspace_type(scope, taxonomy)
    universe_taxonomy = scope == "story" ? "character" : taxonomy
    taxonomy_tabs = if scope == "story"
      STORY_TAG_TYPES.map do |type|
        {
          label: tag_type_label(type),
          path: universe_tags_path(scope: "story", taxonomy: type),
          controller: :tags,
          active: taxonomy == type
        }
      end
    else
      UNIVERSE_TAG_TYPES.map do |type|
        {
          label: tag_type_label(type),
          path: universe_tags_path(scope: "universe", taxonomy: type),
          controller: :tags,
          active: taxonomy == type
        }
      end
    end

    {
      scope_tabs: [
        {
          label: t("tags.scope.universe"),
          path: universe_tags_path(scope: "universe", taxonomy: universe_taxonomy),
          controller: :tags,
          active: scope == "universe"
        },
        {
          label: t("tags.scope.story"),
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
  #
  # These labels belong to the Universe Bible workspaces, which the taxonomy
  # index views also pass their own copy of; both are translated together by the
  # slice that owns those pages.
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

      translated_metadata(metadata).merge(
        count: ordered_records.length,
        nodes: nodes,
        details_url: metadata.fetch(:details_url),
        details_count: ->(tag) { counts.fetch(tag.id, 0) },
        details_count_label: metadata.fetch(:details_count_label),
        modal_fields: public_send(metadata.fetch(:fields), ordered_records)
      )
    end

    # The copy half of a metadata entry, resolved for the locale of the request
    # being rendered. Only the `*_key` entries are translated; the mechanical
    # ones (URLs, the `model_param`) pass through untouched, because a URL and a
    # query value are never chrome.
    #
    # `confirm_message_key` resolves to a lambda rather than a string because the
    # taxonomy tree calls it per tag with the tag as its argument, so the
    # translation has to be interpolated at call time rather than resolved once.
    # Building that lambda here rather than in the constant is what keeps the
    # constant itself free of a `t()` call — which would be evaluated at class
    # load, in whatever locale happened to load it first.
    def translated_metadata(metadata)
      copy = metadata.select { |key, _| key.to_s.end_with?("_key") }
      resolved = copy.to_h do |key, value|
        name = key.to_s.delete_suffix("_key").to_sym

        if name == :confirm_message
          [ name, ->(tag) { t(value, name: tag.name) } ]
        else
          [ name, t(value) ]
        end
      end

      metadata.merge(resolved)
    end
end
