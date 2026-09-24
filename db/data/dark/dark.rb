directory = Rails.root.join("db/data/dark")

models_in_order = [
  User,
  Universe,
  UniverseMembership,
  Story,
  SectionTag,
  Section,
  LocationTag,
  Location,
  CharacterTag,
  Character,
  RelationTag,
  Relation,
  ItemTag,
  Item,
  OwnershipTag,
  Ownership,
  EventTag,
  Event
]

def extract_reference(value, _model)
  object_regex = /\A([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\z/
  tag_slug = nil

  if value.is_a?(String) && value.match(object_regex)
    referenced_model_name = $1
    referenced_model = referenced_model_name.camelize.constantize
    # The referenced model owns slug normalization; the model currently being
    # loaded may be a join/access model without a slug (e.g. UniverseMembership).
    slug = referenced_model.respond_to?(:slugify) ? referenced_model.slugify($2) : $2
    tag_slug = slug if referenced_model_name.end_with?("Tag")
    value = referenced_model.find_by(slug: slug)
  end

  [ value, tag_slug ]
end

models_in_order.each do |model|
  model_name = model.name.underscore.pluralize
  puts "Processing model: #{model_name.green}"

  model_data = YAML.load_file(directory.join("#{model_name}.yml"))

  model_data.each do |yaml_attributes|
    tag_slugs = []
    attributes = {}

    yaml_attributes.each do |key, value|
      if value.is_a?(String)
        value, slug = extract_reference(value, model)
        tag_slugs << slug if slug
      elsif value.is_a?(Array)
        value_and_slugs = value.map { |v| extract_reference(v, model) }
        value = value_and_slugs.map { |v, _| v }
        tag_slugs.concat(value_and_slugs.map { |_, s| s }.compact)

      else
        # value remains the same
      end

      attributes[key] = value
    end

    model.create!(attributes)
    if model_name.end_with?("tags")
      puts "- Created #{model.name}: #{attributes['slug'].cyan}"
    else
      text = attributes["name"] || attributes["slug"] || attributes["access_level"] || "record"
      puts "- Created #{model.name}: #{text.to_s.blue} [#{tag_slugs.join(', ').cyan}]"
    end
  end
end
