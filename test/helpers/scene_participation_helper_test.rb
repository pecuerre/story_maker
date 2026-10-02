require "test_helper"

# The one sentence and the one pair-shape that every Scene participation surface
# used to spell out separately, pinned here before they were given a single home.
#
# All three Scene workspace tabs, the "Appears in Scenes" section on a record's
# own details page, and the Dialogue speaker picker answer the same two questions
# — *what role*, and *which records can I pick* — so a Character linked in one
# place and the same Character on another page have to be described identically.
# Written four and three times over, they could drift: a different fallback
# sentence on one surface, or a `[ id, name ]` pair where the form submits
# `[ name, id ]`, and nothing but a reader comparing two pages would have said so.
class SceneParticipationHelperTest < ActionView::TestCase
  include ApplicationHelper
  include ScenesHelper
  include SceneAppearancesHelper
  include SceneCharactersHelper
  include SceneElementsHelper
  include SceneItemsHelper
  include SceneLocationsHelper

  setup do
    @scene = scenes(:scene_one)
    @link = @scene.scene_characters.first
  end

  test "every participation surface says a blank role the same way" do
    # A blank role is a real state, not a missing value: the author recorded that
    # the record is in the Scene without saying how. All four surfaces fall back to
    # the one sentence for it.
    assert_equal BLANK_ROLE_SENTENCE, scene_character_role_label(participant(role: nil))
    assert_equal BLANK_ROLE_SENTENCE, scene_item_role_label(participant(role: nil))
    assert_equal BLANK_ROLE_SENTENCE, scene_location_role_label(participant(role: nil))
    assert_equal BLANK_ROLE_SENTENCE, scene_appearance_role_label(appearance(role: nil))
  end

  test "every participation surface prefers the author's own role" do
    # The role is free text the application does not interpret, so it is returned
    # unchanged in every language rather than translated.
    assert_equal "Antagonist", scene_character_role_label(participant(role: "Antagonist"))
    assert_equal "Antagonist", scene_item_role_label(participant(role: "Antagonist"))
    assert_equal "Antagonist", scene_location_role_label(participant(role: "Antagonist"))
    assert_equal "Antagonist", scene_appearance_role_label(appearance(role: "Antagonist"))
  end

  test "the blank-role sentence is one key's copy, pinned here so a reword is deliberate" do
    assert_equal "No role recorded", I18n.t("scenes.participation.no_role")
    assert_equal BLANK_ROLE_SENTENCE, I18n.t("scenes.participation.no_role")
  end

  test "a derived speaker has no role on the appearances section, because it is not a stored link" do
    # Only a stored presence link carries a role. A Character who merely speaks has
    # no link, so the section states no role for them rather than inventing one —
    # while the three tabs, whose rows are all stored links, still fall back to the
    # blank-role sentence, which is a different claim about a different thing.
    assert_nil scene_appearance_role_label(appearance(role: nil, linked: nil))
    assert_equal BLANK_ROLE_SENTENCE, scene_character_role_label(participant(role: nil, linked: nil))
  end

  test "every picker builds its pairs the same way from whatever it is offered" do
    # `[ label, value ]` in Rails' order, which is the reverse of what a `data-*`
    # pair or a serialized hash looks like. A reversed pair still renders a
    # full-looking dropdown and submits the wrong value.
    candidates = presenting_characters

    assert_equal candidates.map { |character| [ character.name, character.id ] }, name_id_choices(candidates)
    assert_equal name_id_choices(candidates), scene_character_choices(candidates)
    assert_equal name_id_choices(candidates), scene_item_choices(candidates)
    assert_equal name_id_choices(candidates), scene_element_speaker_choices(candidates)
  end

  test "the speaker picker offers the whole universe while the tab offers the Scene" do
    # The two pickers deliberately answer different questions — who may speak here
    # versus who is here — so the shared pair builder must not be mistaken for a
    # shared candidate list. The speaker picker offers every universe Character,
    # because the same Character may speak in any number of Elements.
    universe_characters = universes(:universe_one).characters.order(:name, :id).to_a

    assert_equal name_id_choices(universe_characters), scene_element_speaker_choices(universe_characters)
    assert_equal presenting_characters.size, scene_character_choices(presenting_characters).size
    assert_operator presenting_characters.size, :<, universe_characters.size
  end

  test "the location picker keeps its own depth-indented path shape" do
    # Locations are the one picker that cannot use the flat pair: a nested place
    # needs its ancestor path so two places called "Room" are not ambiguous, which
    # `LocationPaths` builds from the tree the page was loaded with.
    paths = LocationPaths.build(presenting_locations)

    assert_equal paths.choices, scene_location_choices(paths)
    refute_equal name_id_choices(presenting_locations), paths.choices if nested_locations?
  end

  test "an empty picker offers nothing rather than a blank choice" do
    # A picker with no candidates is different from one offering "no parent", so
    # it stays empty; the blank-first option belongs to the parent selectors.
    assert_empty name_id_choices([])
    assert_empty scene_item_choices([])
  end

  BLANK_ROLE_SENTENCE = "No role recorded"

  private
    def presenting_characters
      @scene.scene_characters.includes(:character).map(&:character).sort_by(&:name)
    end

    def presenting_locations
      @scene.scene_locations.includes(:location).map(&:location).sort_by(&:name)
    end

    def nested_locations?
      presenting_locations.any? { |location| location.parent_id.present? }
    end

    # A `SceneParticipants::Entry`, which is what the three workspace tabs render:
    # its role is read through the stored presence link rather than held directly.
    def participant(role:, linked: true)
      SceneParticipants::Entry.new(
        character: characters(:character_one),
        link: linked ? link_for(role) : nil,
        speaking_elements: []
      )
    end

    # A `SceneAppearances::Entry`, which is what a record's own details page
    # renders. It holds the role directly and knows whether there was a link at all,
    # which is why it can state no role for a derived speaker.
    def appearance(role:, linked: true)
      SceneAppearances::Entry.new(
        scene: @scene,
        linked: linked ? link_for(role) : nil,
        role: role,
        speaking_elements: [],
        event_reference: nil
      )
    end

    def link_for(role)
      @link.dup.tap { |link| link.role = role }
    end
end
