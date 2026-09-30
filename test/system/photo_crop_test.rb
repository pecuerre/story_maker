require "application_system_test_case"

# The photo editor, in a real browser. The request suite proves what the server
# does with a submitted crop; only a browser can show that choosing a file opens
# a square, that the square can be moved without a mouse, and that the finished
# crop is what the record ends up showing.
class PhotoCropTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @character = characters(:character_one)
  end

  test "an author crops a photo onto a character and the details page shows the square" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    open_character_editor
    attach_photo
    assert_selector ".photo-crop", wait: 5
    assert_selector ".photo-crop-stage", wait: 5

    within ".modal.show" do
      click_button "Use this photo"
    end
    assert_text "Photo chosen"
    within ".modal.show" do
      click_button "Save character"
    end
    assert_selector ".entity-row .entity-title", text: @character.name, wait: REFRESH_WAIT

    visit universe_character_path(universe_slug: @universe.slug, id: @character)
    assert_selector "figure.record-photo img"
    assert_equal [ 300, 300 ], stored_photo_dimensions
  end

  test "a record without a photo shows none" do
    sign_in_via_form(@user)
    visit universe_character_path(universe_slug: @universe.slug, id: @character)

    assert_no_selector "figure.record-photo"
    assert_nil @character.reload.photo_id
  end

  test "the square can be moved with the keyboard alone" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    open_character_editor
    attach_photo
    assert_selector ".photo-crop-stage", wait: 5

    # Dragging is a pointer gesture, so the stage has to be operable without one.
    stage = find(".photo-crop-stage")
    stage.send_keys(:arrow_right)
    stage.send_keys(:arrow_down)

    within ".modal.show" do
      click_button "Use this photo"
    end
    assert_text "Photo chosen"
  end

  test "the crop can be abandoned without changing the record" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    open_character_editor
    attach_photo
    assert_selector ".photo-crop-stage", wait: 5

    # The modal's own Cancel sits in the footer beside the cropper's, so each
    # one is addressed by where it is rather than by its label.
    within ".modal.show .photo-crop-controls" do
      click_button "Cancel"
    end

    assert_text "Photo discarded"
    assert_no_selector ".photo-crop"
    within ".modal.show .modal-footer" do
      click_button "Cancel"
    end
    assert_no_selector ".modal.show"
    assert_nil @character.reload.photo_id
  end

  test "an author removes a photo and the details page goes back to none" do
    @character.update!(photo_data: crop_data_url)
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    open_character_editor
    # The row's own picture, which the shared modal loads from the row's values.
    assert_selector ".photo-preview:not([hidden]) img", wait: 5

    check "Remove the current photo"
    assert_text "will be removed"
    within ".modal.show" do
      click_button "Save character"
    end
    assert_selector ".entity-row .entity-title", text: @character.name, wait: REFRESH_WAIT

    visit universe_character_path(universe_slug: @universe.slug, id: @character)
    assert_no_selector "figure.record-photo"
    assert_nil @character.reload.photo_id
  end

  test "a read-only member is offered no cropper at all" do
    private_universe = Universe.create!(owner: @user, name: "Private", slug: "private-photo", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_in_via_form(users(:user_two))
    visit universe_characters_path(universe_slug: private_universe.slug)

    assert_no_selector "[data-controller='photo-crop']"
  end

  private
    def open_character_editor
      within first(".entity-row", text: @character.name) do
        find("button[aria-expanded='false']").click
        assert_selector ".dropdown-menu.show", visible: :visible, wait: 5
        click_button "Edit"
      end
      assert_selector ".modal.show", wait: 10
    end

    # A real, committed image handed to the real file input, so the browser
    # decodes an actual file rather than a stub. The fixture is deliberately not
    # square, which is the case the cropper exists for.
    def attach_photo
      # It used to be drawn with ImageMagick's `convert` into `tmp/`, which is
      # how this case came to need a tool CI does not install.
      path = Rails.root.join("test/fixtures/files/photo_one.jpg")

      within ".modal.show" do
        find(".photo-field input[type=file]").set(path.to_s)
      end
    end

    def crop_data_url
      "data:image/jpeg;base64,#{Base64.strict_encode64(Rails.root.join('db/photos/dark/landscape.jpg').binread)}"
    end

    def stored_photo_dimensions
      PhotoDimensions.of(@character.reload.photo.file.download)
    end
end
