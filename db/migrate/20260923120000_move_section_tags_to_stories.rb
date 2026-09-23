class MoveSectionTagsToStories < ActiveRecord::Migration[8.1]
  def up
    add_reference :section_tags, :story, foreign_key: true

    SectionTag.reset_column_information
    Section.reset_column_information

    # A tag moves to the story of the oldest section that uses it; a tag no
    # section uses goes to the universe's first story. Tags left behind by
    # deleted stories (a universe without any story) are dropped — no section
    # can reference them anymore and the tags page needs a story to exist.
    SectionTag.find_each do |tag|
      story_id = Section.joins(:section_tags)
        .where(sections_section_tags: { section_tag_id: tag.id })
        .order(:id)
        .pick(:story_id)
      story_id ||= Story.where(universe_id: tag.universe_id).order(:id).pick(:id)

      if story_id
        tag.update_columns(story_id: story_id, updated_at: Time.current)
      else
        tag.destroy
      end
    end

    # A tag shared by several stories is copied per story (ancestors included)
    # and the sections are re-pointed, so no section ever references a tag of
    # another story.
    copies = {}
    Section.find_each do |section|
      section.section_tags.to_a.each do |tag|
        next if tag.story_id == section.story_id

        copy = copy_tag(tag, section.story, copies)
        section.section_tags.delete(tag)
        section.section_tags << copy
      end
    end

    change_column_null :section_tags, :story_id, false
    remove_foreign_key :section_tags, :universes
    remove_column :section_tags, :universe_id
  end

  def down
    add_reference :section_tags, :universe, foreign_key: true

    SectionTag.reset_column_information
    SectionTag.find_each do |tag|
      tag.update_columns(universe_id: tag.story.universe_id, updated_at: Time.current)
    end

    change_column_null :section_tags, :universe_id, false
    remove_foreign_key :section_tags, column: :story_id
    remove_column :section_tags, :story_id
  end

  private

  # Copies `tag` (and, recursively, its ancestors) into `story`, once per
  # [tag, story] pair.
  def copy_tag(tag, story, copies)
    key = [ tag.id, story.id ]
    return copies[key] if copies.key?(key)

    parent = tag.parent ? copy_tag(tag.parent, story, copies) : nil
    copy = SectionTag.create!(
      story: story,
      parent: parent,
      name: tag.name,
      description: tag.description,
      bgcolor: tag.bgcolor,
      fgcolor: tag.fgcolor,
      position: tag.position,
      slug: tag.slug
    )
    copy.update_column(:slug, tag.slug)
    copies[key] = copy.id
  end
end
