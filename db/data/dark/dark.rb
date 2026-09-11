directory = Rails.root.join("db/data/dark")

models_in_order = [
  User,
  Story,
  SectionType,
  Section,
]

def extract_reference(value, model)
  object_regex = /\A([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\z/

  if value.is_a?(String) && value.match(object_regex)
    referenced_model_name = $1
    slug = model.slugify($2)
    referenced_model = referenced_model_name.camelize.constantize
    value = referenced_model.find_by(slug: slug)
  end

  value
end

models_in_order.each do |model|
  model_name = model.name.underscore.pluralize
  puts "Processing model: #{model_name.green}"

  model_data = YAML.load_file(directory.join("#{model_name}.yml"))

  model_data.each do |yaml_attributes|
    attributes = {}

    yaml_attributes.each do |key, value|
      if value.is_a?(String)
        value = extract_reference(value, model)
      elsif value.is_a?(Array)
        value = value.map { |v| extract_reference(v, model) }
      else
        # value remains the same
      end

      attributes[key] = value
    end

    model.create!(attributes)
    puts "- Created #{model.name}: #{attributes['slug'].blue}"
  end
end

story = Story.find_by(slug: "dark")

# locations
lt_town = LocationType.create(story: story, name: "Town")
lt_house = LocationType.create(story: story, name: "House")
lt_school = LocationType.create(story: story, name: "School")
lt_police = LocationType.create(story: story, name: "Police")
lt_forest = LocationType.create(story: story, name: "Forest")
lt_cave = LocationType.create(story: story, name: "Cave")
lt_room = LocationType.create(story: story, name: "Room")
l_winden = Location.create(story: story, name: "Winden", location_types: [ lt_town ])
l_jonas_house = Location.create(story: story, name: "Jonas House", location_types: [ lt_house ], parent: l_winden)
l_jonas_room = Location.create(story: story, name: "Jonas Room", location_types: [ lt_room ], parent: l_jonas_house)
l_winden_cave = Location.create(story: story, name: "Winden Cave", location_types: [ lt_cave ], parent: l_winden)

# items
it_key = ItemType.create(story: story, name: "Key")
it_time_machine = ItemType.create(story: story, name: "Time Machine")
i_jonas_key = Item.create(story: story, name: "Jonas Key", item_types: [ it_key ])
i_time_machine = Item.create(story: story, name: "Time Machine", item_types: [ it_time_machine ])

# characters
ct_human = CharacterType.create(story: story, name: "Human")
c_jonas = Character.create(story: story, name: "Jonas", character_types: [ ct_human ])
c_martha = Character.create(story: story, name: "Martha", character_types: [ ct_human ])
c_ulrich = Character.create(story: story, name: "Ulrich", character_types: [ ct_human ])
c_hannah = Character.create(story: story, name: "Hannah", character_types: [ ct_human ])

# relations
rt_friend = RelationType.create(story: story, name: "is friend to", symmetric: true)
rt_parent_child = RelationType.create(story: story, name: "is parent of", symmetric: false, inverse: "is child of")
r_martha_jonas = Relation.create(story: story, relation_types: [ rt_friend ], character1: c_martha, character2: c_jonas)
r_hannah_jonas = Relation.create(story: story, relation_types: [ rt_parent_child ], character1: c_hannah, character2: c_jonas)
r_ulrich_martha = Relation.create(story: story, relation_types: [ rt_parent_child ], character1: c_ulrich, character2: c_martha)

# ownerships
ot_belongs = OwnershipType.create(story: story, name: "belongs to")
ot_holds = OwnershipType.create(story: story, name: "is holded by")
o_time_machine_1 = Ownership.create(story: story, ownership_types: [ ot_belongs ], item: i_time_machine, character: c_jonas)
o_time_machine_2 = Ownership.create(story: story, ownership_types: [ ot_holds ], item: i_time_machine, character: c_martha)
o_time_machine_3 = Ownership.create(story: story, ownership_types: [ ot_holds ], item: i_time_machine, character: c_hannah)

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



