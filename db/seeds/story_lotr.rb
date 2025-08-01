# creating the story
puts "Creating Lord of the Rings story...".yellow.bold
story = Story.find_or_create_by!(name: "Lord of the Rings") do |s|
  s.description = "A high fantasy epic set in Middle-earth, following the quest to destroy the One Ring."
  s.slug = "lotr"
end

# location types
puts "Creating Location Types...".yellow
location_types = [ "Forest", "Mountain", "Village", "Castle", "River" ]
location_type_taxonomy = story.taxonomies.find_by!(name: "Location Types") do |taxonomy|
  taxonomy.description = "Types of locations in the Lord of the Rings story."
end
location_types.each do |type|
  location_type_taxonomy.taxons.find_or_create_by!(name: type)
  puts " * #{type}".green
end
