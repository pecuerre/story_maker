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
  # The copy keys are derived the same way, because every taxonomy's locale block
  # is the same shape and `COPY_SUFFIXES` is that shape written once. Eight
  # hand-written blocks of five keys meant two silent failures: a taxonomy listed
  # without one of them still rendered, because `translated_metadata` merges only
  # the keys a block happens to contain and the tree would have been handed a
  # `nil` where a sentence was expected; and a sentence added to every taxonomy
  # had to be copied into eight places with nothing to catch a missed one.
  #
  # The values are *keys*, not copy: a constant holding translated strings would
  # be built once, in whatever locale loaded the class first, and every later
  # request would render that one language. `tag_workspace_base` resolves them.
  COPY_NAMESPACE = "tags.types"

  COPY_SUFFIXES = {
    title_key: "title",
    description_key: "description",
    empty_description_key: "empty_description",
    read_only_empty_description_key: "read_only_empty_description",
    new_label_key: "new_label"
  }.freeze

  # The copy a taxonomy needs beyond the five every taxonomy has. The Scene
  # taxonomy is the only one today: its delete confirmation is a lambda the tree
  # calls per tag, because "Delete “<name>” and its children?" cannot be
  # resolved once for a whole page.
  EXTRA_COPY_SUFFIXES = { "scene" => { confirm_message_key: "delete_confirm" } }.freeze

  # A module function rather than an instance method on purpose: this runs while
  # the constants below are being built, and a view helper here would be callable
  # from a template for no reason.
  def self.tag_copy_metadata(type)
    COPY_SUFFIXES.merge(EXTRA_COPY_SUFFIXES.fetch(type, {}))
      .to_h { |key, suffix| [ key, "#{COPY_NAMESPACE}.#{type}.#{suffix}" ] }
  end

  UNIVERSE_TAG_METADATA = UNIVERSE_TAG_TYPES.to_h { |type| [ type, tag_copy_metadata(type) ] }.freeze

  # The per-type copy for this story's section and scene taxonomies.
  STORY_TAG_METADATA = STORY_TAG_TYPES.to_h { |type| [ type, tag_copy_metadata(type) ] }.freeze

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
  # A tab label is the name of the workspace it opens, and every workspace names
  # itself in its own key block, so the strip reads `<workspace>.tabs.<name>`
  # rather than a second hand-written list here. A workspace the strip does not
  # open — Ownerships reached from the Items strip, Relations from the Characters
  # strip — still declares the label, because this method builds the whole strip
  # for both of them and a workspace that cannot render its own tab is the kind of
  # hole a missing translation only shows at runtime.
  #
  # `path` is a route helper's **name**, not a lambda. A constant is loaded once
  # and its lambdas capture the module, which has no route helpers, so calling
  # `universe_characters_path` inside one raises `undefined local variable or
  # method … for module TagsHelper`. `public_send` runs it on the view, which is
  # the same reason `UNIVERSE_TAG_METADATA` above stores `model_param` and a
  # field-helper name rather than calling either from the constant.
  CONTENT_WORKSPACE_TABS = {
    "character" => {
      key: "characters",
      tabs: [
        { name: "characters", path: :universe_characters_path, controller: :characters },
        { name: "relations", path: :universe_relations_path, controller: :relations }
      ]
    },
    "location" => {
      key: "locations",
      tabs: [
        { name: "locations", path: :universe_locations_path, controller: :locations }
      ]
    },
    "event" => {
      key: "events",
      tabs: [
        { name: "events", path: :universe_events_path, controller: :events },
        { name: "timeline", path: :universe_timeline_path, controller: :timeline }
      ]
    },
    "item" => {
      key: "items",
      tabs: [
        { name: "items", path: :universe_items_path, controller: :items },
        { name: "ownerships", path: :universe_ownerships_path, controller: :ownerships }
      ]
    }
  }.freeze

  # A taxonomy tag's own identity card, as the two shapes `shared/_record_details`
  # accepts: the description across the card's full width, and the tag's settings
  # as a compact footer line.
  #
  # The scope is derived from the record rather than passed in, so a taxonomy can
  # never disagree with its own model about who owns it: a story-scoped tag has a
  # `story_id`, and everything else belongs to the universe. The explanation of
  # what a scope means is the same `scope_*_description` copy the grid used to
  # show inline — it moved behind the footer's info button rather than being
  # reworded, because no reader needs it while scanning the tagged records.
  def tag_identity_details(tag)
    scope = tag.respond_to?(:story_id) ? "story" : "universe"

    {
      wide_facts: [
        detail_fact(t("tags.show.description"), tag.description,
          blank: t("tags.show.description_blank"))
      ],
      footer: [
        {
          text: t("tags.show.scope_line.#{scope}"),
          hint: t("tags.show.scope_#{scope}_description"),
          hint_label: t("tags.show.scope_hint_label")
        },
        { text: t("tags.show.color_line", color: tag.bgcolor) }
      ]
    }
  end

  def content_workspace_tabs(type, active_tag: nil)
    type = type.to_s
    workspace = CONTENT_WORKSPACE_TABS[type]
    return [] if workspace.nil?

    base_tabs = workspace.fetch(:tabs).map do |tab|
      {
        label: t("#{workspace.fetch(:key)}.tabs.#{tab.fetch(:name)}"),
        path: public_send(tab.fetch(:path)),
        controller: tab.fetch(:controller)
      }
    end

    base_tabs.each do |tab|
      tab[:active] = active_tag.nil? && controller.controller_name == tab.fetch(:controller).to_s
    end

    menu_tags = Current.universe.public_send(:"#{type}_tags").where(show_in_menu: true).order(:position, :id)
    tag_tabs = menu_tags.map do |tag|
      {
        # A pinned tag's name is the author's own words, so it is data and is
        # never translated — unlike the workspace tab above it.
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
      # One query for the whole taxonomy. `includes(:children)` reached the first
      # level only and every deeper level asked again, so the tree descends
      # through this index instead; the photo comes with it because the editor
      # carries each node's stored image.
      hierarchy = HierarchyIndex.build(records.includes(:photo))
      counts = tagged_record_counts(records)

      translated_metadata(metadata).merge(
        count: hierarchy.records.length,
        nodes: hierarchy.roots,
        hierarchy: hierarchy,
        details_url: metadata.fetch(:details_url),
        details_count: ->(tag) { counts.fetch(tag.id, 0) },
        details_count_label: metadata.fetch(:details_count_label),
        modal_fields: public_send(metadata.fetch(:fields), hierarchy.records)
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
