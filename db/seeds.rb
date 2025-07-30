# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create a sample story to demonstrate the fixed taxonomies
puts "Creating sample story..."

story = Story.find_or_create_by!(name: "Sample Fantasy Story") do |s|
  s.description = "A sample story to demonstrate the taxonomy system"
  s.slug = "sample-fantasy-story"
end

puts "Sample story created: #{story.name}"
puts "Fixed taxonomies will be automatically created for each new story"
puts "Current story has #{story.taxonomies.count} taxonomies"
