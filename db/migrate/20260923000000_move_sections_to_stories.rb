class MoveSectionsToStories < ActiveRecord::Migration[8.1]
  def up
    add_column :stories, :slug, :string
    add_reference :sections, :story, foreign_key: { to_table: :stories }

    Story.reset_column_information
    Story.find_each do |story|
      story.update_columns(slug: unique_slug(story.universe_id, story.name.presence || "story"))
    end

    change_column_null :stories, :slug, false
    add_index :stories, [ :universe_id, :slug ], unique: true

    Section.reset_column_information

    # Every universe that already has sections gets a story to hold them:
    # reuse its first story or create a default one.
    Section.distinct.pluck(:universe_id).each do |universe_id|
      story = Story.where(universe_id: universe_id).order(:id).first
      story ||= Story.create!(
        universe_id: universe_id,
        name: "Main story",
        slug: unique_slug(universe_id, "Main story")
      )
      Section.where(universe_id: universe_id, story_id: nil)
        .update_all(story_id: story.id, updated_at: Time.current)
    end

    change_column_null :sections, :story_id, false

    remove_foreign_key :sections, :universes
    remove_column :sections, :universe_id

    Section.reset_column_information
  end

  def down
    add_column :sections, :universe_id, :integer
    Section.reset_column_information

    Section.find_each do |section|
      section.update_columns(universe_id: section.story.universe_id)
    end

    change_column_null :sections, :universe_id, false
    add_index :sections, :universe_id
    add_foreign_key :sections, :universes

    remove_column :sections, :story_id
    remove_index :stories, column: [ :universe_id, :slug ]
    remove_column :stories, :slug

    Section.reset_column_information
    Story.reset_column_information
  end

  private

  def unique_slug(universe_id, name)
    base = Story.slugify(name).presence || "story"
    slug = base
    suffix = 2

    while Story.exists?(universe_id: universe_id, slug: slug)
      slug = "#{base}-#{suffix}"
      suffix += 1
    end

    slug
  end
end
