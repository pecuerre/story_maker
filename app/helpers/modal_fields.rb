module ModalFields
  # Builds a flat, depth-indented [id, label] list of taxonomy nodes suitable for a parent-select dropdown.
  def taxonomy_parent_options(nodes)
    by_parent = nodes.group_by(&:parent_id)
    options = [ [ "", "(No parent)" ] ]
    add_children = lambda do |parent_id, depth|
      (by_parent[parent_id] || []).each do |node|
        options << [ node.id, ("— " * depth) + node.name ]
        add_children.call(node.id, depth + 1)
      end
    end
    add_children.call(nil, 0)
    options
  end

  def event_fields_json(event)
    {
      title: event.title,
      start_datetime: event.start_datetime&.strftime("%Y-%m-%dT%H:%M"),
      end_datetime: event.end_datetime&.strftime("%Y-%m-%dT%H:%M"),
      before_event_id: event.before_event_id,
      after_event_id: event.after_event_id,
      simultaneous_event_id: event.simultaneous_event_id,
      description: event.description,
      event_tag_ids: event.event_tag_ids
    }.to_json
  end

  def event_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      }
    ]
  end

  def character_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      }
    ]
  end

  def character_fields_json(character)
    {
      name: character.name,
      description: character.description,
      character_tag_ids: character.character_tag_ids
    }.to_json
  end

  def item_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      }
    ]
  end

  def item_fields_json(item)
    {
      name: item.name,
      description: item.description,
      item_tag_ids: item.item_tag_ids
    }.to_json
  end

  def location_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      }
    ]
  end

  def location_taxonomy_fields(location_tags)
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "location_tag_ids",
        label: "Location tags",
        type: "select",
        multiple: true,
        options: location_tags.map { |location_tag|
          [ location_tag.id, location_tag.name ]
        }
      }
    ]
  end

  def ownership_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      }
    ]
  end

  def ownership_fields_json(ownership)
    {
      item_id: ownership.item_id,
      character_id: ownership.character_id,
      ownership_tag_ids: ownership.ownership_tag_ids,
      description: ownership.description,
      from_date: ownership.from_date&.strftime("%Y-%m-%dT%H:%M"),
      to_date: ownership.to_date&.strftime("%Y-%m-%dT%H:%M")
    }.to_json
  end

  def relation_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      },
      {
        name: "symmetric",
        label: "Symmetric",
        type: "checkbox"
      },
      {
        name: "inverse",
        label: "Inverse",
        type: "text",
        required_unless: { field: "symmetric", value: true }
      }
    ]
  end

  def relation_fields_json(relation)
    {
      character1_id: relation.character1_id,
      character2_id: relation.character2_id,
      relation_tag_ids: relation.relation_tag_ids,
      description: relation.description,
      from_date: relation.from_date&.strftime("%Y-%m-%dT%H:%M"),
      to_date: relation.to_date&.strftime("%Y-%m-%dT%H:%M")
    }.to_json
  end

  def section_tag_taxonomy_fields(nodes = [])
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "bgcolor",
        label: "Background color",
        type: "color"
      },
      {
        name: "fgcolor",
        label: "Foreground color",
        type: "color"
      },
      {
        name: "parent_id",
        label: "Parent",
        type: "select",
        options: taxonomy_parent_options(nodes)
      }
    ]
  end

  def section_taxonomy_fields(section_tags)
    [
      {
        name: "name",
        label: "Name",
        type: "text",
        required: true
      },
      {
        name: "description",
        label: "Description",
        type: "textarea"
      },
      {
        name: "section_tag_ids",
        label: "Section tags",
        type: "select",
        multiple: true,
        options: section_tags.map { |section_tag|
          [ section_tag.id, section_tag.name ]
        }
      }
    ]
  end
end
