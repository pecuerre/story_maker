require "test_helper"

# An optional reference id that names no record is a *field* error, not a
# database failure.
#
# The foreign keys in this schema are real, so an unknown `parent_id` or
# `before_event_id` used to reach the write and come back as
# `ActiveRecord::InvalidForeignKey` — an unhandled 500, outside the documented
# error hash that every JSON mutation answers a rejected save with. The
# validation belongs in the model rather than in a controller, because the id
# can arrive from a form, from the development-data loader, or from a console.
#
# The three implementations are `Hierarchical#parent_reference_exists`,
# `Event#temporal_references_exist`, and `Scene#optional_references_exist`;
# these tests pin all three so a fourth optional reference cannot be added
# without the rule.
class UnknownReferenceTest < ActiveSupport::TestCase
  MISSING_ID = 999_999

  setup do
    @universe = universes(:universe_one)
  end

  test "an unknown parent is rejected on the parent attribute" do
    character = Character.new(name: "Dangling", universe: @universe, parent_id: MISSING_ID)

    assert_not character.valid?
    assert_equal [ I18n.t("shared.errors.hierarchy.must_exist") ], character.errors[:parent]
  end

  test "an unknown parent is rejected on every hierarchical model" do
    # One rule in `Hierarchical` serves all fourteen models that include it, so
    # the models that own the two possible scopes are checked by name: a
    # universe-scoped content record, a tag, and the story-scoped models that
    # override the scope.
    story = stories(:story_one)

    {
      Character => { universe: @universe },
      Location => { universe: @universe },
      Item => { universe: @universe },
      CharacterTag => { universe: @universe, name: "Tag", bgcolor: "#d3d3d3", fgcolor: "#000000" },
      Section => { story: story, name: "Section" },
      SectionTag => { story: story, name: "Tag", bgcolor: "#d3d3d3", fgcolor: "#000000" }
    }.each do |model, attributes|
      record = model.new(attributes.merge(parent_id: MISSING_ID))

      assert_not record.valid?, "#{model.name} accepted a parent that does not exist"
      assert_equal [ I18n.t("shared.errors.hierarchy.must_exist") ], record.errors[:parent],
        "#{model.name} did not report the unknown parent on the parent attribute"
    end
  end

  test "an existing parent in the same scope is still accepted" do
    character = Character.new(name: "Nested", universe: @universe, parent_id: characters(:character_one).id)

    assert character.valid?, character.errors.full_messages.join(", ")
  end

  test "a parent in another scope is reported as the scope error, not as a missing record" do
    foreign = universes(:universe_two).characters.create!(name: "Foreign character")
    character = Character.new(name: "Foreign child", universe: @universe, parent_id: foreign.id)

    assert_not character.valid?
    assert_equal [ I18n.t("shared.errors.same_scope.universe") ], character.errors[:parent]
  end

  test "an unparseable parent id is rejected rather than written as zero" do
    # Active Record casts a non-numeric string to `0` for an integer column, so
    # without this rule "abc" would be written as `parent_id = 0` and refused by
    # the foreign key.
    character = Character.new(name: "Nonsense", universe: @universe, parent_id: "abc")

    assert_not character.valid?
    assert_equal [ I18n.t("shared.errors.hierarchy.must_exist") ], character.errors[:parent]
  end

  test "an absent parent stays valid" do
    assert Character.new(name: "Root", universe: @universe).valid?
  end

  test "every unknown temporal reference is rejected on its own attribute" do
    %i[before_event after_event simultaneous_event].each do |name|
      event = Event.new(title: "Dangling reference", universe: @universe, "#{name}_id": MISSING_ID)

      assert_not event.valid?, "Event accepted an unknown #{name}"
      assert_equal [ I18n.t("events.errors.must_exist") ], event.errors[name],
        "Event did not report an unknown #{name} on the #{name} attribute"
    end
  end

  test "a reference-only event reports both that the reference and the identity are missing" do
    event = Event.new(universe: @universe, before_event_id: MISSING_ID)

    assert_not event.valid?
    assert_equal [ I18n.t("events.errors.must_exist") ], event.errors[:before_event]
    assert_equal [ I18n.t("events.errors.must_be_identifiable") ], event.errors[:base]
  end

  test "a known temporal reference in the same universe is still accepted" do
    event = Event.new(title: "Later", universe: @universe, before_event_id: events(:event_one).id)

    assert event.valid?, event.errors.full_messages.join(", ")
  end

  test "a temporal reference in another universe is reported as the scope error" do
    event = Event.new(title: "Foreign reference", universe: @universe,
      before_event_id: events(:event_other_universe).id)

    assert_not event.valid?
    assert_equal [ I18n.t("events.errors.must_belong_to_universe") ], event.errors[:before_event]
  end

  test "an unknown optional Scene reference is rejected the same way" do
    scene = Scene.new(name: "Dangling", story: stories(:story_one), section_id: MISSING_ID)

    assert_not scene.valid?
    assert_equal [ I18n.t("scenes.errors.must_exist") ], scene.errors[:section]
  end
end
