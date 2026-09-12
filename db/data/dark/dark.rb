directory = Rails.root.join("db/data/dark")

models_in_order = [
  User,
  Story,
  SectionType,
  Section,
  LocationType,
  Location,
  CharacterType,
  Character,
  RelationType,
  Relation,
]

def extract_reference(value, model)
  object_regex = /\A([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\z/
  type_slug = nil

  if value.is_a?(String) && value.match(object_regex)
    referenced_model_name = $1
    slug = model.slugify($2)
    type_slug = slug if referenced_model_name.end_with?("Type")
    referenced_model = referenced_model_name.camelize.constantize
    value = referenced_model.find_by(slug: slug)
  end

  [value, type_slug]
end

models_in_order.each do |model|
  model_name = model.name.underscore.pluralize
  puts "Processing model: #{model_name.green}"

  model_data = YAML.load_file(directory.join("#{model_name}.yml"))

  model_data.each do |yaml_attributes|
    type_slugs = []
    attributes = {}

    yaml_attributes.each do |key, value|
      if value.is_a?(String)
        value, slug = extract_reference(value, model)
        type_slugs << slug if slug
      elsif value.is_a?(Array)
        value_and_slugs = value.map { |v| extract_reference(v, model) }
        value = value_and_slugs.map { |v, _| v }
        type_slugs.concat(value_and_slugs.map { |_, s| s }.compact)

      else
        # value remains the same
      end

      attributes[key] = value
    end

    model.create!(attributes)
    if model_name.end_with?("types")
      puts "- Created #{model.name}: #{attributes['slug'].cyan}"
    else
      text = attributes['name'] || attributes['slug']
      puts "- Created #{model.name}: #{text.blue} [#{type_slugs.join(', ').cyan}]"
    end
  end
end

story = Story.find_by(slug: "dark")

# items
it_key = ItemType.create(story: story, name: "Key")
it_time_machine = ItemType.create(story: story, name: "Time Machine")
i_jonas_key = Item.create(story: story, name: "Jonas Key", item_types: [ it_key ])
i_time_machine = Item.create(story: story, name: "Time Machine", item_types: [ it_time_machine ])

# ownerships
# ot_belongs = OwnershipType.create(story: story, name: "belongs to")
# ot_holds = OwnershipType.create(story: story, name: "is holded by")
# o_time_machine_1 = Ownership.create(story: story, ownership_types: [ ot_belongs ], item: i_time_machine, character: c_jonas)
# o_time_machine_2 = Ownership.create(story: story, ownership_types: [ ot_holds ], item: i_time_machine, character: c_martha)
# o_time_machine_3 = Ownership.create(story: story, ownership_types: [ ot_holds ], item: i_time_machine, character: c_hannah)

e_jonas_bartosz = Event.create(story: story, title: "Jonas meets Bartosz", start_datetime: "2024-01-01T10:00", end_datetime: "2024-01-01T11:00")
e_ulrich_hannah = Event.create(story: story, title: "Ulrich meets Hannah", start_datetime: "2024-01-02T10:00", end_datetime: "2024-01-02T11:00")
e_conversation_1 = Event.create(story: story, title: "Conversation 1", after_event: e_ulrich_hannah)
e_conversation_2 = Event.create(story: story, title: "Conversation 2", after_event: e_conversation_1)
e_time_travel = Event.create(story: story, title: "Time Travel", simultaneous_event: e_ulrich_hannah)
e_dinner = Event.create(story: story, title: "Dinner", after_event: e_conversation_2)
e_party = Event.create(story: story, title: "Party", after_event: e_dinner)
e_farewell = Event.create(story: story, title: "Farewell", after_event: e_party)
e_reunion = Event.create(story: story, title: "Reunion", after_event: e_dinner)
e_explosion = Event.create(story: story, title: "Explosion", simultaneous_event: e_party)
e_meeting = Event.create(story: story, title: "Meeting", before_event: e_explosion)
e_work = Event.create(story: story, title: "Work", after_event: e_conversation_1)



