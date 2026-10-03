require "test_helper"

class DraftTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @author = users(:user_one)
  end

  test "a draft belongs to one author in one universe" do
    draft = Draft.new(user: @author, universe: @universe)

    assert draft.save
    assert_equal @author, draft.user
    assert_equal @universe, draft.universe
  end

  test "requires an author and a universe" do
    assert_not Draft.new(universe: @universe).valid?
    assert_not Draft.new(user: @author).valid?
  end

  test "starts life as a working draft" do
    # The column default and the model's own `draft?` have to agree, because the
    # editing flow resumes "the draft" without reading the string first. A row
    # written without a status must therefore be the state it claims to be.
    draft = Draft.create!(user: @author, universe: @universe)

    assert_equal "draft", draft.status
    assert_predicate draft, :draft?
    assert_predicate draft, :open?
  end

  test "refuses a status nothing in the application behaves for" do
    # Same reasoning as `Universe::COLLABORATION_MODES`: a status outside the list
    # would be a draft that no control can apply or discard, and the reader would
    # find that out by watching a button do nothing.
    draft = Draft.new(user: @author, universe: @universe, status: "merged")

    assert_not draft.valid?
    assert_includes draft.errors[:status], "is not included in the list"
  end

  test "names each stored status rather than leaving callers to compare strings" do
    # The mode predicates on `Universe` exist for the same reason: a caller that
    # writes `status == "applied"` re-derives the vocabulary and can disagree with
    # the column about what counts as done.
    draft = Draft.new(user: @author, universe: @universe)

    assert_predicate draft, :draft?
    assert_not draft.applied?

    draft.update!(status: "applied")
    assert_predicate draft, :applied?
    assert_not draft.open?

    draft.update!(status: "discarded")
    assert_predicate draft, :discarded?

    draft.update!(status: "submitted")
    assert_predicate draft, :submitted?
    # A submitted draft is waiting for a reviewer, not finished, so it is still
    # open — but re-applying it is the reviewing workflow's decision, not its
    # author's.
    assert_predicate draft, :open?
  end

  test "changes read in the order they were written and go with the draft" do
    draft = Draft.create!(user: @author, universe: @universe)
    character = characters(:character_one)
    first = draft.draft_changes.create!(
      record_type: "Character", record_id: character.id, action: "update",
      payload: { "name" => "Marth" }, base_version: DraftChange.capture_base_version(character)
    )
    second = draft.draft_changes.create!(record_type: "Character", action: "create", payload: { "name" => "Lysander" })

    assert_equal [ first, second ], draft.draft_changes.reload.to_a

    assert_difference("DraftChange.count", -2) do
      draft.destroy
    end
  end

  test "a payload survives the round trip as a hash" do
    # The applier reads these as a `Hash`, not as the JSON text they are stored
    # as, so the cast is part of the column's contract rather than an accident of
    # the JSON type.
    draft = Draft.create!(user: @author, universe: @universe)
    change = draft.draft_changes.create!(
      record_type: "Character", action: "create", payload: { "name" => "Ariadne", "position" => 3 }
    )

    assert_equal({ "name" => "Ariadne", "position" => 3 }, change.reload.payload)
    assert_kind_of Hash, change.payload
  end

  test "an author can have more than one draft in a universe" do
    # There is no unique index, and deliberately so: an applied draft stays behind
    # as history, so a constraint across every status would make a second editing
    # session impossible. "One open draft" is a rule of the editing flow, not of
    # the schema.
    first = Draft.create!(user: @author, universe: @universe)
    first.update!(status: "applied")

    second = Draft.create!(user: @author, universe: @universe)

    assert_equal [ first, second ], @author.drafts.order(:id).to_a
    assert_equal 2, Draft.where(user: @author, universe: @universe).count
  end

  test "a destroyed universe leaves no draft behind" do
    draft = Draft.create!(user: @author, universe: @universe)
    draft.draft_changes.create!(record_type: "Character", action: "create", payload: { "name" => "Ariadne" })

    @universe.destroy

    assert_not Draft.exists?(draft.id)
    # Named rather than counted, for the reason `DiscussionTest` gives: these
    # tables have no fixture files, so counting the whole table would measure the
    # test database's history instead of the cascade.
    assert_not DraftChange.exists?(draft_id: draft.id)
    assert_empty Draft.where(universe_id: @universe.id)
  end
end
