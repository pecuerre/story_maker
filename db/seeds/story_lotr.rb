#####
##### creating the story
#####
puts "Creating Lord of the Rings story...".yellow.bold
story = Story.find_or_create_by!(name: "Lord of the Rings") do |s|
  s.description = "A high fantasy epic set in Middle-earth, following the quest to destroy the One Ring."
  s.slug = "lotr"
end

#####
##### creating location types
#####
puts "Creating Location Types...".yellow

location_types = [
  "Region",
  "Kingdom",
  "Forest",
  "Mountain",
  "Village",
  "Castle",
  "River"
]
location_type_taxonomy = story.taxonomies.find_by!(name: "Location Types") do |taxonomy|
  taxonomy.description = "Types of locations in the Lord of the Rings story."
end

location_types.each do |type|
  location_type_taxonomy.taxons.find_or_create_by!(name: type)
  puts " * #{type}".green
end

#####
##### creating locations
#####
puts "Creating Locations...".yellow

locations = [
  { name: "Middle-earth", parent: nil, description: "The fictional world where the story takes place.", type: "World" },
  { name: "Eriador", parent: "Middle-earth", description: "A region in the northwest of Middle-earth, home to the Shire and Bree.", type: "Region" },
  { name: "Kingdom of Arnor", parent: "Eriador",  description: "A kingdom in Eriador, known for its ancient ruins and history.", type: "Kingdom" },
  { name: "The Shire", parent: "Kingdom of Arnor", description: "A peaceful region inhabited by Hobbits.", type: "Village" },
  { name: "Mordor", description: "A dark and desolate land, home to Sauron.", type: "Mountain" },
  { name: "Rivendell", description: "An Elven refuge known for its beauty and wisdom.", type: "Forest" },
  { name: "Helm's Deep", description: "A fortress in the mountains, site of a great battle.", type: "Castle" },
  { name: "Anduin River", description: "The Great River of Middle-earth, flowing through many lands.", type: "River" }
]

list = {}
locations.each do |location|
  item = story.locations.find_or_create_by!(name: location[:name]) do |loc|
    loc.description = location[:description]
    loc.location_type = location_type_taxonomy.taxons.find_by!(name: location[:type])
    loc.parent = list[location[:parent]] if location[:parent]
  end
  list[location[:name]] = item
  puts " * #{location[:name]} (#{location[:type]})".green
end
