require "test_helper"

# A photo is carried through the same mutation every other field is: the editor
# posts the square it cropped as one ordinary form field, and the server turns it
# into a stored image. These are the three flows that have to work — the JSON
# modals, the taxonomy editor's modal, and a plain full-page form — plus the
# cases where a photo must not be assignable at all.
class PhotoMutationTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @crop = data_url(Rails.root.join("db/photos/dark/landscape.jpg").binread)
    sign_in_as(users(:user_one))
  end

  # -------------------------------------------------------------- the JSON modal

  test "a character editor posts a crop and the record keeps it" do
    assert_difference -> { @universe.characters.count } do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Jonas with a photo", photo_data: @crop } },
        as: :json
    end

    assert_response :created
    character = @universe.characters.find_by!(name: "Jonas with a photo")
    assert character.photo.present?
    assert_equal @universe.id, character.photo.universe_id
  end

  test "an item editor replaces an existing photo" do
    item = items(:item_one)
    item.update!(photo_data: @crop)
    previous = item.photo_id

    patch universe_item_url(universe_slug: @universe.slug, id: item),
      params: { item: { name: item.name, photo_data: @crop } },
      as: :json

    assert_response :success
    assert_not_equal previous, item.reload.photo_id
    assert_not Photo.exists?(previous)
  end

  test "an event editor removes a photo" do
    event = events(:event_one)
    event.update!(photo_data: @crop)
    photo_id = event.photo_id

    patch universe_event_url(universe_slug: @universe.slug, id: event),
      params: { event: { title: event.title, remove_photo: "1" } },
      as: :json

    assert_response :success
    assert_nil event.reload.photo_id
    assert_not Photo.exists?(photo_id)
  end

  test "an unreadable crop is a 422 with the error the editor renders" do
    character = characters(:character_one)

    assert_no_difference -> { Photo.count } do
      patch universe_character_url(universe_slug: @universe.slug, id: character),
        params: { character: {
          name: character.name,
          photo_data: data_url("not an image at all")
        } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "could not be read as an image" ], response.parsed_body["photo"]
  end

  test "a photo_id in the payload is not a field the server accepts" do
    # The editor never sends an id, so there is no value here that could point at
    # another universe's photo. A cross-universe assignment is not reachable
    # through a request at all.
    character = characters(:character_one)
    foreign = create_photo(universe: @other_universe)

    patch universe_character_url(universe_slug: @universe.slug, id: character),
      params: { character: { name: character.name, photo_id: foreign.id } },
      as: :json

    assert_response :success
    assert_nil character.reload.photo_id
  end

  # -------------------------------------------------------- the taxonomy editor

  test "a tag editor posts a crop through the taxonomy modal" do
    tag = @universe.character_tags.first

    patch universe_character_tag_url(universe_slug: @universe.slug, id: tag),
      params: { character_tag: { name: tag.name, photo_data: @crop } },
      as: :json

    assert_response :success
    assert_equal @universe.id, tag.reload.photo.universe_id
  end

  test "a location editor posts a crop through the tree modal" do
    location = @universe.locations.first

    patch universe_location_url(universe_slug: @universe.slug, id: location),
      params: { location: { name: location.name, photo_data: @crop } },
      as: :json

    assert_response :success
    assert_equal @universe.id, location.reload.photo.universe_id
  end

  test "a section tag editor posts a crop through the tree modal" do
    story = stories(:story_one)
    tag = story.section_tags.first

    patch universe_story_section_tag_url(universe_slug: @universe.slug, story_id: story, id: tag),
      params: { section_tag: { name: tag.name, photo_data: @crop } },
      as: :json

    assert_response :success
    assert_equal @universe.id, tag.reload.photo.universe_id
  end

  # ------------------------------------------------- the plain full-page forms

  test "a story form posts a crop" do
    story = @universe.stories.first

    patch universe_story_url(universe_slug: @universe.slug, id: story),
      params: { story: { name: story.name, photo_data: @crop } }

    assert_response :redirect
    assert_equal @universe.id, story.reload.photo.universe_id
  end

  test "a scene form posts a crop" do
    story = stories(:story_one)
    scene = story.scenes.first

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: story, id: scene),
      params: { scene: { name: scene.name, photo_data: @crop } }

    assert_response :redirect
    assert_equal @universe.id, scene.reload.photo.universe_id
  end

  test "a universe form posts a crop" do
    patch universe_url(universe_slug: @universe.slug),
      params: { universe: { name: @universe.name, photo_data: @crop } }

    assert_response :redirect
    assert_equal @universe.id, @universe.reload.photo.universe_id
  end

  # ------------------------------------------------------------- authorization

  test "a read-only member cannot post a photo" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    character = private_universe.characters.create!(name: "Readable")
    sign_out
    sign_in_as(users(:user_two))

    patch universe_character_url(universe_slug: private_universe.slug, id: character),
      params: { character: { name: character.name, photo_data: @crop } },
      as: :json

    assert_response :forbidden
    assert_nil character.reload.photo_id
  end

  test "a guest cannot post a photo to a public universe" do
    character = @universe.characters.create!(name: "Guest readable")
    sign_out

    patch universe_character_url(universe_slug: @universe.slug, id: character),
      params: { character: { name: character.name, photo_data: @crop } },
      as: :json

    assert_redirected_to new_session_url
    assert_nil character.reload.photo_id
  end

  private
    def data_url(bytes, type: "image/jpeg")
      "data:#{type};base64,#{Base64.strict_encode64(bytes)}"
    end
end
