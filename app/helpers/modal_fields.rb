module ModalFields
  # Builds a flat, depth-indented [id, label] list of taxonomy nodes suitable for a parent-select dropdown.
  def taxonomy_parent_options(nodes)
    by_parent = nodes.group_by(&:parent_id)
    options = [ [ "", t("modal_fields.no_parent") ] ]
    add_children = lambda do |parent_id, depth|
      (by_parent[parent_id] || []).each do |node|
        options << [ node.id, ("— " * depth) + node.name ]
        add_children.call(node.id, depth + 1)
      end
    end
    add_children.call(nil, 0)
    options
  end

  # One field descriptor with its label resolved for the request being rendered.
  #
  # The descriptors below hold `label_key:` rather than `label:`. A descriptor is
  # serialized into the taxonomy tree's `data-taxonomy-tree-modal-fields-value`
  # and printed by a modal the browser builds from it, so the label is chrome that
  # has to cross the boundary already translated — but `PHOTO_FIELD` is a frozen
  # constant, and a constant that called `t()` would be resolved once, in whatever
  # locale happened to load this class first, and every later request would render
  # that one language. The key therefore travels in the constant and the string is
  # produced here, per request.
  #
  # The key is dropped on the way out. It is how the label is found, not part of
  # the descriptor's contract with the tree controller, and leaving it in the
  # serialized JSON would publish a key nobody renders.
  def modal_field(descriptor)
    key = descriptor[:label_key]
    return descriptor if key.nil?

    descriptor.except(:label_key).merge(label: t(key))
  end

  # The editor fields shared by every taxonomy. `nodes` is the one per-call
  # value (the ordered node list the parent selector is built from);
  # `extra_fields` appends type-specific descriptors after the shared ones.
  # The shared taxonomy editor renders and submits a checkbox like any other
  # field, so `taggable` needs no per-type wiring.
  # Every photo-capable editor carries an optional photo. The descriptor names a
  # widget rather than an input: the taxonomy controller builds the same
  # container `shared/_photo_field` renders, and `photo_crop_controller.js` fills
  # it.
  #
  # `url: true` says the value this descriptor carries is the record's stored
  # image rather than one of its columns, which the taxonomy node resolves
  # through `record_photo_url`. The submitted field names (`photo_data`,
  # `remove_photo`) belong to the widget, not to this descriptor.
  PHOTO_FIELD = {
    name: "photo",
    label_key: "modal_fields.photo",
    type: "photo",
    url: true
  }.freeze

  def taxonomy_tag_fields(nodes = [], extra_fields = [])
    [
      {
        name: "name",
        label_key: "modal_fields.name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label_key: "modal_fields.description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label_key: "modal_fields.background_color",
        type: "color"
      },
      {
        name: "fgcolor",
        label_key: "modal_fields.foreground_color",
        type: "color"
      },
      {
        name: "parent_id",
        label_key: "modal_fields.parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      },
      {
        name: "taggable",
        label_key: "modal_fields.taggable",
        type: "checkbox"
      },
      photo_field,
      *extra_fields
    ].map { |field| modal_field(field) }
  end

  # The one descriptor every photo-capable editor shares, so the field cannot be
  # spelled one way in a tag taxonomy and another in a content editor.
  def photo_field
    modal_field(PHOTO_FIELD)
  end

  # Character, Location, Item, and Event tags additionally offer the workspace
  # menu tab. Relation, Ownership, Section, and Scene tags do not.
  def content_tag_taxonomy_fields(nodes = [])
    taxonomy_tag_fields(nodes, [
      {
        name: "show_in_menu",
        label_key: "modal_fields.show_in_menu",
        type: "checkbox"
      }
    ])
  end

  # The value a `datetime-local` control has to carry, from a stored column.
  #
  # One named expression rather than `&.strftime(DATETIME_LOCAL_FORMAT)` written
  # at each call site, because the six in-world datetimes this application
  # serializes had drifted before: they were formatted with a minute-precision
  # format that dropped the stored second, so opening an editor and saving it
  # again rewrote the column. A single call site cannot drift from itself, and
  # `test/helpers/modal_fields_helper_test.rb` holds what it produces.
  #
  # This is the *control's* format, not the reader's. `DATE_FORMAT` is what a
  # reader is shown and stays minute-precision; a `datetime-local` control cannot
  # hold a second unless it carries `step: 1`, which every control fed by this one
  # does. `ScenesHelper#scene_datetime_field_value` is the Scene form's version of
  # the same rule, and it additionally keeps a rejected raw value so a validation
  # error does not clear the input.
  def datetime_local_value(datetime)
    datetime&.strftime(ApplicationHelper::DATETIME_LOCAL_FORMAT)
  end

  def event_fields_json(event)
    {
      title: event.title,
      start_datetime: datetime_local_value(event.start_datetime),
      end_datetime: datetime_local_value(event.end_datetime),
      before_event_id: event.before_event_id,
      after_event_id: event.after_event_id,
      simultaneous_event_id: event.simultaneous_event_id,
      description: event.description,
      event_tag_ids: event.event_tag_ids,
      photo_url: record_photo_url(event)
    }.to_json
  end

  def event_tag_taxonomy_fields(nodes = [])
    content_tag_taxonomy_fields(nodes)
  end

  def character_tag_taxonomy_fields(nodes = [])
    content_tag_taxonomy_fields(nodes)
  end

  def character_fields_json(character)
    {
      name: character.name,
      description: character.description,
      character_tag_ids: character.character_tag_ids,
      photo_url: record_photo_url(character)
    }.to_json
  end

  def item_tag_taxonomy_fields(nodes = [])
    content_tag_taxonomy_fields(nodes)
  end

  def item_fields_json(item)
    {
      name: item.name,
      description: item.description,
      item_tag_ids: item.item_tag_ids,
      photo_url: record_photo_url(item)
    }.to_json
  end

  def location_tag_taxonomy_fields(nodes = [])
    content_tag_taxonomy_fields(nodes)
  end

  # The editor the two hierarchical, tag-selecting records share.
  #
  # Location and Section are the only two models with both a parent and a tag
  # assignment, so they are the only two editors with a parent selector beside a
  # tag selector. They were maintained separately and had to be kept in step by
  # hand; they differ in two values and nothing else — which field carries the tag
  # ids, and what that selector is called — so those are the only two arguments.
  #
  # `tags` and `parents` are the two per-call lists: the parent's own editor is
  # built from its siblings and its tag selector from its taxonomy's tags. The
  # option *value* is an id in both selectors, and the option *text* is the
  # author's own record name, so neither is translated — only the blank parent's
  # label and the two selectors' own labels are chrome.
  def nested_record_taxonomy_fields(tags, parents = [], tag_field:, tag_label_key:)
    [
      {
        name: "name",
        label_key: "modal_fields.name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label_key: "modal_fields.description",
        type: "textarea"
      },
      {
        name: "parent_id",
        label_key: "modal_fields.parent",
        type: "select",
        options: taxonomy_parent_options(parents)
      },
      {
        name: tag_field,
        label_key: tag_label_key,
        type: "select",
        multiple: true,
        options: tags.map { |tag| [ tag.id, tag.name ] }
      },
      photo_field
    ].map { |field| modal_field(field) }
  end

  def location_taxonomy_fields(location_tags, locations = [])
    nested_record_taxonomy_fields(location_tags, locations,
      tag_field: "location_tag_ids",
      tag_label_key: "modal_fields.location_tags")
  end

  def ownership_tag_taxonomy_fields(nodes = [])
    taxonomy_tag_fields(nodes)
  end

  def ownership_fields_json(ownership)
    {
      name: ownership.name,
      item_id: ownership.item_id,
      character_id: ownership.character_id,
      ownership_tag_ids: ownership.ownership_tag_ids,
      description: ownership.description,
      from_date: datetime_local_value(ownership.from_date),
      to_date: datetime_local_value(ownership.to_date),
      photo_url: record_photo_url(ownership)
    }.to_json
  end

  def relation_tag_taxonomy_fields(nodes = [])
    taxonomy_tag_fields(nodes, [
      {
        name: "symmetric",
        label_key: "modal_fields.symmetric",
        type: "checkbox"
      },
      {
        name: "inverse",
        label_key: "modal_fields.inverse",
        type: "text",
        required_unless: { field: "symmetric", value: true }
      }
    ])
  end

  def relation_fields_json(relation)
    {
      name: relation.name,
      character1_id: relation.character1_id,
      character2_id: relation.character2_id,
      relation_tag_ids: relation.relation_tag_ids,
      description: relation.description,
      from_date: datetime_local_value(relation.from_date),
      to_date: datetime_local_value(relation.to_date),
      photo_url: record_photo_url(relation)
    }.to_json
  end

  def section_tag_taxonomy_fields(nodes = [])
    taxonomy_tag_fields(nodes)
  end

  def scene_tag_taxonomy_fields(nodes = [])
    taxonomy_tag_fields(nodes)
  end

  def section_taxonomy_fields(section_tags, sections = [])
    nested_record_taxonomy_fields(section_tags, sections,
      tag_field: "section_tag_ids",
      tag_label_key: "modal_fields.section_tags")
  end
end
