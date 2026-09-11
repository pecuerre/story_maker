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
      event_type_id: event.event_type_id
    }.to_json
  end

  def event_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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

  def character_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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
      character_type_id: character.character_type_id
    }.to_json
  end

  def item_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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
      item_type_id: item.item_type_id
    }.to_json
  end

  def location_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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

  def location_taxonomy_fields(location_types)
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
        name: "location_type_id",
        label: "Location type",
        type: "select",
        required: true,
        options: location_types.map { |location_type|
          [ location_type.id, location_type.name ]
        }
      }
    ]
  end

  def ownership_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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
      ownership_type_id: ownership.ownership_type_id,
      description: ownership.description,
      from_date: ownership.from_date&.strftime('%Y-%m-%dT%H:%M'),
      to_date: ownership.to_date&.strftime('%Y-%m-%dT%H:%M')
    }.to_json
  end

  def relation_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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
      relation_type_id: relation.relation_type_id,
      description: relation.description,
      from_date: relation.from_date&.strftime('%Y-%m-%dT%H:%M'),
      to_date: relation.to_date&.strftime('%Y-%m-%dT%H:%M')
    }.to_json
  end

  def section_type_taxonomy_fields(nodes = [])
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
        name: "color",
        label: "Color",
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

  def section_taxonomy_fields(section_types)
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
        name: "section_type_id",
        label: "Section type",
        type: "select",
        required: true,
        options: section_types.map { |section_type|
          [ section_type.id, section_type.name ]
        }
      }
    ]
  end
end