# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create sample taxonomies
puts "Creating taxonomies..."

# Categories taxonomy
categories_taxonomy = Taxonomy.find_or_create_by!(slug: "categories") do |t|
  t.name = "Categories"
  t.description = "Main content categories for organizing stories and content"
  t.fixed = true
end

# Tags taxonomy
tags_taxonomy = Taxonomy.find_or_create_by!(slug: "tags") do |t|
  t.name = "Tags"
  t.description = "Flexible tagging system for content"
  t.fixed = false
end

# Genres taxonomy
genres_taxonomy = Taxonomy.find_or_create_by!(slug: "genres") do |t|
  t.name = "Genres"
  t.description = "Story genres and themes"
  t.fixed = false
end

puts "Creating taxons..."

# Add taxons to Categories taxonomy
categories_root = categories_taxonomy.taxons.first
fiction = categories_taxonomy.taxons.find_or_create_by!(name: "Fiction", parent: categories_root)
non_fiction = categories_taxonomy.taxons.find_or_create_by!(name: "Non-Fiction", parent: categories_root)

# Fiction subcategories
categories_taxonomy.taxons.find_or_create_by!(name: "Fantasy", parent: fiction)
categories_taxonomy.taxons.find_or_create_by!(name: "Science Fiction", parent: fiction)
categories_taxonomy.taxons.find_or_create_by!(name: "Mystery", parent: fiction)
categories_taxonomy.taxons.find_or_create_by!(name: "Romance", parent: fiction)

# Non-Fiction subcategories
categories_taxonomy.taxons.find_or_create_by!(name: "History", parent: non_fiction)
categories_taxonomy.taxons.find_or_create_by!(name: "Science", parent: non_fiction)
categories_taxonomy.taxons.find_or_create_by!(name: "Biography", parent: non_fiction)

# Add taxons to Tags taxonomy
tags_root = tags_taxonomy.taxons.first
tags_taxonomy.taxons.find_or_create_by!(name: "Adventure", parent: tags_root)
tags_taxonomy.taxons.find_or_create_by!(name: "Drama", parent: tags_root)
tags_taxonomy.taxons.find_or_create_by!(name: "Comedy", parent: tags_root)
tags_taxonomy.taxons.find_or_create_by!(name: "Thriller", parent: tags_root)
tags_taxonomy.taxons.find_or_create_by!(name: "Educational", parent: tags_root)

# Add taxons to Genres taxonomy
genres_root = genres_taxonomy.taxons.first
action = genres_taxonomy.taxons.find_or_create_by!(name: "Action", parent: genres_root)
drama = genres_taxonomy.taxons.find_or_create_by!(name: "Drama", parent: genres_root)
comedy = genres_taxonomy.taxons.find_or_create_by!(name: "Comedy", parent: genres_root)

# Action subgenres
genres_taxonomy.taxons.find_or_create_by!(name: "Martial Arts", parent: action)
genres_taxonomy.taxons.find_or_create_by!(name: "Military", parent: action)
genres_taxonomy.taxons.find_or_create_by!(name: "Sports", parent: action)

# Drama subgenres
genres_taxonomy.taxons.find_or_create_by!(name: "Historical Drama", parent: drama)
genres_taxonomy.taxons.find_or_create_by!(name: "Political Drama", parent: drama)
genres_taxonomy.taxons.find_or_create_by!(name: "Family Drama", parent: drama)

puts "Seed data created successfully!"
puts "Created #{Taxonomy.count} taxonomies with #{Taxon.count} total taxons"
