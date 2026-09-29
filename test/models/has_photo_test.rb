require "test_helper"

# The rules `HasPhoto` states, proved against one universe-scoped record, one
# story-scoped record, and a tag: the photo is optional everywhere, a photo from
# another universe can never be assigned, and a save that fails never takes the
# current photo away with it.
class HasPhotoTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @crop = "data:image/jpeg;base64,#{Base64.strict_encode64(Rails.root.join("db/photos/dark/landscape.jpg").binread)}"
  end

  test "a record with no photo is valid" do
    Photo::OWNER_CLASS_NAMES.each do |name|
      record = build_record(name)
      record.valid?
      assert_empty record.errors.where(:photo), "#{name} must not require a photo"
    end
  end

  test "an uploaded crop becomes a photo inside the record's own universe" do
    character = @universe.characters.create!(name: "With a photo", photo_data: @crop)

    assert character.photo.present?
    assert_equal @universe.id, character.photo.universe_id
  end

  test "a story-scoped record's photo belongs to its story's universe" do
    story = @universe.stories.first
    section = story.sections.create!(name: "With a photo", photo_data: @crop)
    scene = story.scenes.create!(name: "With a photo", photo_data: @crop)
    scene_tag = story.scene_tags.create!(name: "With a photo", photo_data: @crop)

    [ section, scene, scene_tag ].each do |record|
      assert_equal @universe.id, record.photo.universe_id, "#{record.class} resolved the wrong universe"
    end
  end

  test "a universe's own photo belongs to that universe" do
    universe = Universe.new(name: "Self scoped", owner: users(:user_one), photo_data: @crop)
    universe.save!

    assert_equal universe.id, universe.photo.universe_id
  end

  test "a photo from another universe is refused" do
    foreign = create_photo(universe: @other_universe)
    character = @universe.characters.new(name: "Foreign", photo_id: foreign.id)

    assert_not character.valid?
    assert_includes character.errors.full_messages, "Photo must belong to the same universe"
  end

  test "a record with no universe cannot take a photo" do
    character = Character.new(name: "Ownerless", photo_data: @crop)

    assert_not character.valid?
    assert_includes character.errors.full_messages, "Photo needs a record that belongs to a universe"
  end

  test "replacing a photo destroys the one it superseded" do
    character = @universe.characters.create!(name: "Replaced", photo_data: @crop)
    first = character.photo_id

    character.update!(photo_data: @crop)

    assert_not_equal first, character.photo_id
    assert_not Photo.exists?(first), "the superseded photo should be gone"
  end

  test "removing a photo clears the reference and destroys the row" do
    character = @universe.characters.create!(name: "Removed", photo_data: @crop)
    photo_id = character.photo_id

    character.update!(remove_photo: "1")

    assert_nil character.reload.photo_id
    assert_not Photo.exists?(photo_id)
  end

  test "an editor that sends nothing leaves the photo alone" do
    character = @universe.characters.create!(name: "Untouched", photo_data: @crop)
    photo_id = character.photo_id

    character.update!(name: "Renamed")

    assert_equal photo_id, character.reload.photo_id
  end

  test "a photo shared with another record is not destroyed by a replacement" do
    # An upload always creates a new row, so nothing shares one in the interface.
    # Development data and a console can, and the photo must not be taken away
    # from a record that still points at it.
    shared = create_photo(universe: @universe)
    first = @universe.characters.create!(name: "Shares", photo_id: shared.id)
    second = @universe.characters.create!(name: "Also shares", photo_id: shared.id)

    first.update!(photo_data: @crop)

    assert Photo.exists?(shared.id), "a shared photo must survive another record replacing it"
    assert_equal shared.id, second.reload.photo_id
  end

  test "a rejected save keeps the photo the record already had" do
    character = @universe.characters.create!(name: "Kept", photo_data: @crop)
    photo_id = character.photo_id
    character.name = ""

    assert_not character.save
    assert Photo.exists?(photo_id), "a refused save must not take the current photo away"
  end

  test "a rejected removal keeps the photo the record already had" do
    character = @universe.characters.create!(name: "Kept", photo_data: @crop)
    photo_id = character.photo_id
    character.name = ""
    character.remove_photo = "1"

    assert_not character.save
    assert Photo.exists?(photo_id)
  end

  test "an unreadable upload is an ordinary field error, not an exception" do
    character = @universe.characters.new(
      name: "Broken",
      photo_data: "data:image/png;base64,#{Base64.strict_encode64('not an image')}"
    )

    assert_no_difference -> { Photo.count } do
      assert_not character.save
    end
    assert_includes character.errors.full_messages, "Photo could not be read as an image"
  end

  test "a soft delete keeps the photo so a restore brings it back" do
    character = @universe.characters.create!(name: "Soft deleted", photo_data: @crop)
    photo_id = character.photo_id

    character.soft_delete
    assert Photo.exists?(photo_id), "a soft delete keeps the row, so it keeps the photo"

    character.restore
    assert_equal photo_id, character.reload.photo_id
  end

  private
    # One record of each kind, so "optional everywhere" is proved for all of them
    # rather than for the one this test happens to use.
    def build_record(class_name)
      case class_name
      when "Universe" then Universe.new(name: "No photo", owner: users(:user_one))
      when "Story" then @universe.stories.new(name: "No photo")
      when "Section" then @universe.stories.first.sections.new(name: "No photo")
      when "Scene" then @universe.stories.first.scenes.new(name: "No photo")
      when "SectionTag" then @universe.stories.first.section_tags.new(name: "No photo")
      when "SceneTag" then @universe.stories.first.scene_tags.new(name: "No photo")
      when "Relation" then Relation.new(character1: characters(:character_one), character2: characters(:character_two))
      when "Ownership" then Ownership.new(character: characters(:character_one), item: items(:item_one))
      else
        model = class_name.constantize
        model.new(universe: @universe, name: "No photo")
      end
    end
end
