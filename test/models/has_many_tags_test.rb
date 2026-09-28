require "test_helper"

class HasManyTagsTest < ActiveSupport::TestCase
  test "same-scope assignments and association builds retain their owning scope" do
    character = characters(:character_one)
    character_tag = character_tags(:character_tag_two)

    character.update!(character_tag_ids: [ character_tag.id ])
    assert_equal [ character_tag.id ], character.reload.character_tag_ids
    assert_equal character.universe_id, character.character_tags.build(name: "Built tag").universe_id
    assert_equal character_tag.universe_id, character_tag.characters.build(name: "Built character").universe_id

    section = sections(:section_one)
    section_tag = section_tags(:section_tag_two)

    section.update!(section_tag_ids: [ section_tag.id ])
    assert_equal [ section_tag.id ], section.reload.section_tag_ids
    assert_equal section.story_id, section.section_tags.build(name: "Built section tag").story_id
    assert_equal section_tag.story_id, section_tag.sections.build(name: "Built section").story_id

    scene = scenes(:scene_one)
    scene_tag = scene_tags(:scene_tag_two)

    scene.update!(scene_tag_ids: [ scene_tag.id ])
    assert_equal [ scene_tag.id ], scene.reload.scene_tag_ids
    assert_equal scene.story_id, scene.scene_tags.build(name: "Built scene tag").story_id
    assert_equal scene_tag.story_id, scene_tag.scenes.build(name: "Built scene").story_id
  end

  test "rejects tag IDs from another universe on every universe-scoped content model" do
    scoped_records = [
      [ characters(:character_one), :character_tag_ids, :character_tags, character_tags(:character_tag_three) ],
      [ locations(:location_one), :location_tag_ids, :location_tags, location_tags(:location_tag_three) ],
      [ items(:item_one), :item_tag_ids, :item_tags, item_tags(:item_tag_three) ],
      [ events(:event_one), :event_tag_ids, :event_tags, event_tags(:event_tag_three) ]
    ]

    scoped_records.each do |record, id_writer, association, foreign_tag|
      original_tag_ids = record.public_send(association).ids.sort

      assert_not record.update(id_writer => [ foreign_tag.id ]),
        "expected #{record.class} to reject #{foreign_tag.class} from another universe"
      assert_includes record.errors[association], "must belong to the same universe"
      assert_equal original_tag_ids, record.reload.public_send(association).ids.sort
    end
  end

  test "association reads hide corrupt cross-universe join rows on both sides" do
    scoped_records = [
      [ :characters_character_tags, characters(:character_one), character_tags(:character_tag_three), :characters ],
      [ :locations_location_tags, locations(:location_one), location_tags(:location_tag_three), :locations ],
      [ :items_item_tags, items(:item_one), item_tags(:item_tag_three), :items ],
      [ :events_event_tags, events(:event_one), event_tags(:event_tag_three), :events ]
    ]

    scoped_records.each do |join_table, record, foreign_tag, inverse_association|
      insert_join_row(join_table, record, foreign_tag)

      assert_not_includes record.reload.public_send(foreign_tag.model_name.plural), foreign_tag
      assert_not_includes foreign_tag.reload.public_send(inverse_association), record
    end
  end

  test "the database rejects a legacy join row that references a missing record" do
    character_id = characters(:character_one).id

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO characters_character_tags (character_id, character_tag_id)
        VALUES (#{character_id}, 2147483647)
      SQL
    end

    section_id = sections(:section_one).id

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO sections_section_tags (section_id, section_tag_id)
        VALUES (#{section_id}, 2147483647)
      SQL
    end
  end

  test "the database rejects a duplicate legacy join row" do
    insert_join_row(:characters_character_tags, characters(:character_one), character_tags(:character_tag_two))

    assert_raises(ActiveRecord::RecordNotUnique) do
      insert_join_row(:characters_character_tags, characters(:character_one), character_tags(:character_tag_two))
    end
  end

  test "section tag associations use story scope on both sides" do
    section = sections(:section_one)
    foreign_tag = section_tags(:section_tag_three)
    insert_join_row(:sections_section_tags, section, foreign_tag)

    assert_not_includes section.reload.section_tags, foreign_tag
    assert_not_includes foreign_tag.reload.sections, section
  end

  test "scene tag associations use story scope on both sides" do
    scene = scenes(:scene_one)
    foreign_tag = scene_tags(:scene_tag_three)
    insert_join_row(:scenes_scene_tags, scene, foreign_tag)

    assert_not_includes scene.reload.scene_tags, foreign_tag
    assert_not_includes foreign_tag.reload.scenes, scene
  end

  test "inverse assignments reject content from another owning scope" do
    character_tag = character_tags(:character_tag_one)
    original_character_ids = character_tag.character_ids
    foreign_character = Character.create!(universe: universes(:universe_two), name: "Foreign character")

    assert_not character_tag.update(character_ids: [ foreign_character.id ])
    assert_includes character_tag.errors[:characters], "must belong to the same universe"
    assert_equal original_character_ids, character_tag.reload.character_ids

    section_tag = section_tags(:section_tag_one)
    original_section_ids = section_tag.section_ids
    foreign_section = Section.create!(story: stories(:story_two), name: "Foreign section")

    assert_not section_tag.update(section_ids: [ foreign_section.id ])
    assert_includes section_tag.errors[:sections], "must belong to the same story"
    assert_equal original_section_ids, section_tag.reload.section_ids
  end

  test "a tag lists the records carrying it and a content model has no such list" do
    character_tag = character_tags(:character_tag_one)
    character = characters(:character_one)
    character.update!(character_tag_ids: [ character_tag.id ])

    assert_equal [ character.id ], character_tag.tagged_records.pluck(:id)
    assert_equal [ character ], character_tag.tagged_records.to_a
    assert_empty characters(:character_one).tagged_records
    assert_nil Character.tagged_records_association
    assert_equal :characters, CharacterTag.tagged_records_association
  end

  test "a tag's record list stays inside its own universe and story" do
    character_tag = character_tags(:character_tag_one)
    insert_join_row(:characters_character_tags, characters(:character_one), character_tags(:character_tag_three))

    assert_empty character_tags(:character_tag_three).tagged_records
    assert_equal [ characters(:character_one).id ], character_tag.tagged_records.pluck(:id)

    section_tag = section_tags(:section_tag_one)
    insert_join_row(:sections_section_tags, sections(:section_one), section_tags(:section_tag_three))

    assert_empty section_tags(:section_tag_three).tagged_records
    assert_equal [ sections(:section_one).id ], section_tag.tagged_records.pluck(:id)
  end

  test "a tag's record list is ordered by name" do
    tag = character_tags(:character_tag_one)
    tag.update!(character_ids: [ characters(:character_one).id, characters(:character_two).id ])

    assert_equal characters(:character_one, :character_two).map(&:name), tag.tagged_records.map(&:name)
  end

  test "rejects a universe change while tag assignments exist" do
    character = Character.create!(universe: universes(:universe_one), name: "Tagged mover",
      character_tag_ids: [ character_tags(:character_tag_one).id ])

    assert_not character.update(universe: universes(:universe_two))
    assert_includes character.errors[:universe_id], "cannot be changed while tagged records exist"
    assert_equal universes(:universe_one).id, character.reload.universe_id
  end

  test "rejects a universe change on the tag side while records carry the tag" do
    tag = CharacterTag.create!(universe: universes(:universe_one), name: "Mover tag")
    tag.update!(character_ids: [ characters(:character_one).id ])

    assert_not tag.update(universe: universes(:universe_two))
    assert_includes tag.errors[:universe_id], "cannot be changed while tagged records exist"
    assert_equal universes(:universe_one).id, tag.reload.universe_id
  end

  test "rejects a story change on a section tag while sections carry the tag" do
    tag = SectionTag.create!(story: stories(:story_one), name: "Mover section tag")
    tag.update!(section_ids: [ sections(:section_one).id ])

    assert_not tag.update(story: stories(:story_alt))
    assert_includes tag.errors[:story_id], "cannot be changed while tagged records exist"
    assert_equal stories(:story_one).id, tag.reload.story_id
  end

  test "allows a universe change without tag assignments" do
    character = Character.create!(universe: universes(:universe_one), name: "Untagged mover")

    assert character.update(universe: universes(:universe_two))
    assert_equal universes(:universe_two).id, character.reload.universe_id
  end

  private
    def insert_join_row(join_table, record, tag)
      connection = ActiveRecord::Base.connection
      connection.execute(<<~SQL.squish)
        INSERT INTO #{join_table} (#{record.class.model_name.element}_id, #{tag.class.model_name.element}_id)
        VALUES (#{record.id}, #{tag.id})
      SQL
    end
end
