require "test_helper"

# What one remembered change's apply decided, kept after the run.
#
# `test/services/draft_applier_test.rb` writes these rows and holds them against the
# applier's own vocabulary. What is only answerable here is the model: which states
# a row may hold, that it is append-only like the change it describes, that it
# cannot claim a draft its change does not belong to, and that it goes when the
# draft does.
class DraftChangeOutcomeTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @author = users(:user_one)
    @character = characters(:character_one)
    @draft = Draft.create!(user: @author, universe: @universe)
  end

  test "the stored states are the applier's own vocabulary plus written" do
    assert_equal "written", DraftChangeOutcome::WRITTEN
    assert_equal DraftApplier::SKIP_REASONS.map(&:to_s), DraftChangeOutcome::SKIP_REASONS
    assert_equal %w[written moved deleted missing gone unplaceable refused], DraftChangeOutcome::STATES
  end

  test "a state outside the vocabulary is refused rather than stored" do
    outcome = build_outcome(state: "probably")

    assert_not outcome.valid?
    assert_includes outcome.errors[:state], "is not included in the list"
  end

  test "an answer is one of the two the resolution page offers, or none" do
    assert build_outcome(answer: "mine").valid?
    assert build_outcome(answer: "theirs").valid?
    assert build_outcome(answer: nil).valid?, "a change nobody had to decide about carries no answer"
    assert_not build_outcome(answer: "perhaps").valid?
  end

  test "the three predicates are the applier's own three states" do
    written = build_outcome(state: "written")
    kept = build_outcome(state: "moved", answer: "theirs")
    skipped = build_outcome(state: "refused")

    assert_predicate written, :written?
    assert_not_predicate written, :kept?
    assert_not_predicate written, :skipped?

    # A change answered "theirs" is not written, but it is not a refusal either:
    # the author decided, and the draft's history counts it apart from a skip.
    assert_not_predicate kept, :written?
    assert_predicate kept, :kept?
    assert_not_predicate kept, :skipped?

    assert_predicate skipped, :skipped?
    assert_not_predicate skipped, :written?
    assert_not_predicate skipped, :kept?
  end

  test "an outcome cannot claim a draft its change does not belong to" do
    elsewhere = Draft.create!(user: users(:user_two), universe: universes(:universe_two))
    outcome = build_outcome(draft: elsewhere)

    assert_not outcome.valid?
    # The same sentence a change gives when it names a record from another
    # universe: two columns that disagree are refused rather than resolved.
    assert_includes outcome.errors[:draft], I18n.t("shared.errors.same_scope.draft")
  end

  test "an outcome is append-only, like the change it describes" do
    outcome = create_outcome

    assert_raises ActiveRecord::ReadOnlyRecord do
      outcome.update!(state: "refused")
    end
    # The remembered change refuses a rewrite for the same reason and in the same
    # shape: what a run decided is a statement about one moment, and an editable
    # row would let the history drift away from what happened.
    assert_equal "written", outcome.reload.state
  end

  test "a change reads its own outcome, and a change nobody applied has none" do
    remembered = remember_create

    assert_nil remembered.outcome, "an open draft has no outcome to draw, and none is invented"

    outcome = create_outcome(draft_change: remembered)

    assert_equal outcome, remembered.reload.outcome
  end

  test "an outcome goes when its change does, and when its draft does" do
    remembered = remember_create
    create_outcome(draft_change: remembered)
    other = remember_create("Another")
    create_outcome(draft_change: other)

    remembered.destroy

    assert_not DraftChangeOutcome.exists?(draft_change: remembered)

    @draft.destroy

    assert_empty DraftChangeOutcome.where(draft: @draft), "an outcome is a statement about a run inside its draft"
  end

  private

    def remember_create(name = "A remembered create")
      @draft.draft_changes.create!(action: "create", record_type: "Character",
        payload: { "name" => name, "universe_id" => @universe.id })
    end

    def build_outcome(state: "written", answer: nil, draft: @draft, draft_change: nil)
      DraftChangeOutcome.new(state: state, answer: answer, draft: draft,
        draft_change: draft_change || remember_create, created_at: Time.current)
    end

    def create_outcome(**attributes)
      build_outcome(**attributes).tap(&:save!)
    end
end
