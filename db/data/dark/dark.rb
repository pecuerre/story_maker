directory = Rails.root.join("db/data/dark")

models_in_order = [
  User,
  Universe,
  SectionType,
  Section,
  LocationType,
  Location,
  CharacterType,
  Character,
  RelationType,
  Relation,
  ItemType,
  Item,
  OwnershipType,
  Ownership,
  EventType,
  Event
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
