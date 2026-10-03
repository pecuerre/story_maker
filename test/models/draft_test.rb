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

  test "history is kept, but only one draft can be open at a time" do
    # An applied draft stays behind as history, which is why the unique index is
    # partial rather than covering every status: a second editing session needs a
    # row of its own. What it must not allow is a second *unfinished* draft for the
    # same author in the same universe, because applying both would write the
    # second one's changes over whatever the first one left (ADR 0022).
    first = Draft.create!(user: @author, universe: @universe)
    first.update!(status: "applied")

    second = Draft.create!(user: @author, universe: @universe)

    assert_equal [ first, second ], @author.drafts.order(:id).to_a
    assert_equal 2, Draft.where(user: @author, universe: @universe).count

    assert_raises ActiveRecord::RecordNotUnique do
      Draft.create!(user: @author, universe: @universe)
    end

    # The same rule for a discarded draft, and for another author's draft: the
    # index is per author and per universe, not a claim on the whole universe.
    # Closing the second draft is also what frees the slot for the next session.
    second.update!(status: "discarded")
    assert_equal 0, Draft.open.where(user: @author, universe: @universe).count
    assert_nil Draft.open_for(@author, @universe)
    assert Draft.create!(user: @author, universe: @universe).persisted?
    assert Draft.create!(user: users(:user_two), universe: @universe).persisted?
    assert Draft.create!(user: @author, universe: universes(:universe_two)).persisted?
  end

  test "the unique index covers exactly the open statuses" do
    # The migration froze the statuses in SQL, because a migration has to keep
    # saying what it said on the day it ran, so the duplication is real and this
    # is what holds it. If a status joined `OPEN_STATUSES` without joining the
    # index, two drafts that both count as open could exist — the exact pair the
    # index exists to refuse.
    index = Draft.connection.indexes(:drafts).find { |candidate| candidate.name == "index_drafts_on_user_and_universe_while_open" }

    assert index&.unique, "one open draft per author per universe is a database rule, not only an application one"
    assert_equal %w[user_id universe_id], index.columns
    assert_equal Draft::OPEN_STATUSES.sort, quoted_statuses(index.where).sort
  end

  test "an author resumes the one open draft rather than the most recent of several" do
    # The `open` scope names the statuses the index protects, so the finder and the
    # constraint cannot disagree about which rows are "open".
    finished = Draft.create!(user: @author, universe: @universe)
    finished.update!(status: "applied")
    open = Draft.create!(user: @author, universe: @universe)

    assert_equal open, Draft.open_for(@author, @universe)
    assert_equal open, Draft.open_for!(@author, @universe)
    assert_nil Draft.open_for(@author, universes(:universe_two)),
      "a draft in another universe is another scope, and must not be resumed from this one"
  end

  test "the open draft is the author's most recent unfinished one, and only theirs" do
    foreign_author = Draft.create!(user: users(:user_two), universe: @universe)
    foreign_author.update!(status: "applied")

    assert_nil Draft.open_for(@author, @universe), "an author with no unfinished draft has none to resume"
    assert_nil Draft.open_for(@author, universes(:universe_two)), "a draft in another universe is another scope"

    first = Draft.create!(user: @author, universe: @universe)
    assert_equal first, Draft.open_for(@author, @universe)

    # An applied draft is history, so the next unfinished one is what an author
    # resuming their work means.
    first.update!(status: "discarded")
    second = Draft.create!(user: @author, universe: @universe)
    assert_equal second, Draft.open_for(@author, @universe)

    # A submitted draft is waiting for a reviewer, so it is still the one an author
    # is working in, and it must not be opened a second time.
    second.update!(status: "submitted")
    assert_equal second, Draft.open_for(@author, @universe)
    assert_equal second, Draft.open_for!(@author, @universe)
  end

  test "opening a draft creates one only when there is none to resume" do
    assert_difference -> { Draft.count }, 1 do
      opened = Draft.open_for!(@author, @universe)

      assert_predicate opened, :open?
      assert_equal "draft", opened.status
    end

    resumed = Draft.open_for!(@author, @universe)

    assert_no_difference -> { Draft.count } do
      assert_equal resumed, Draft.open_for!(@author, @universe)
    end
  end

  test "two requests that open a draft at once end up on the same one" do
    # The race the partial unique index creates: both requests read "no open
    # draft", both insert, and the index refuses the second. Raising here would
    # fail one author's edit over the other's timing and would leave a draft behind
    # that can never be created again — so the loser re-reads the winner's row and
    # both requests' changes belong to one draft.
    #
    # The race itself cannot be staged with two live connections inside a
    # transactional test, so each half is forced in turn: the read that happens
    # before the winner's row is there, and the insert the index refuses.
    winner = Draft.create!(user: @author, universe: @universe)
    reads = 0

    with_stubbed_class_methods(
      Draft,
      open_for: ->(*) { reads += 1; reads == 1 ? nil : winner },
      create!: ->(*) { raise ActiveRecord::RecordNotUnique, "index_drafts_on_user_and_universe_while_open" }
    ) do
      assert_no_difference -> { Draft.count } do
        assert_equal winner, Draft.open_for!(@author, @universe)
      end
    end
  end

  test "a lost race that cannot find the winner's draft is not swallowed" do
    # The rescue re-reads rather than inventing an answer. If the row is gone again
    # — the winner's transaction rolled back after the index refused the loser —
    # there is nothing to resume, and a nil answer would hand the caller a
    # draft-less session to remember changes into.
    with_stubbed_class_methods(
      Draft,
      open_for: ->(*) { nil },
      create!: ->(*) { raise ActiveRecord::RecordNotUnique, "index_drafts_on_user_and_universe_while_open" }
    ) do
      assert_raises ActiveRecord::RecordNotUnique do
        Draft.open_for!(@author, @universe)
      end
    end
  end

  test "the pending count is this author's own open changes and nothing else" do
    draft = Draft.create!(user: @author, universe: @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character", payload: { "name" => "Ariadne" })
    draft.draft_changes.create!(action: "update", record_type: "Character", record_id: characters(:character_one).id,
      payload: { "name" => "Marth" }, base_version: DraftChange.capture_base_version(characters(:character_one)))

    assert_equal 2, Draft.pending_changes_count(@author, @universe)
    assert_equal 0, Draft.pending_changes_count(users(:user_two), @universe),
      "another author's pending work is not part of this reader's count"
    assert_equal 0, Draft.pending_changes_count(@author, universes(:universe_two)),
      "a draft in another universe is another scope"

    # A closed draft's changes are history, so they stop being pending the moment
    # the draft is applied or discarded — the count is what is left to write, not
    # what this author has ever typed.
    draft.update!(status: "applied")
    assert_equal 0, Draft.pending_changes_count(@author, @universe)

    assert_equal 0, Draft.pending_changes_count(nil, @universe),
      "a guest has no draft, so asking must not raise"
    assert_equal 0, Draft.pending_changes_count(@author, nil)
  end

  test "the open scope and the predicate name the same statuses" do
    draft = Draft.create!(user: @author, universe: @universe)

    Draft::STATUSES.each do |status|
      draft.update!(status: status)

      assert_equal draft.open?, Draft.open.where(id: draft.id).exists?,
        "`open` and `open?` must answer the same question, or a draft the finder resumes is one the " \
        "apply workflow would not touch"
    end
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

  private
    # The statuses a partial index's `where` names, read out of its SQL rather than
    # out of the migration, because the migration is a frozen record and this is
    # the check that keeps it honest against the model.
    def quoted_statuses(predicate)
      predicate.scan(/'([^']+)'/).flatten
    end

    # Swap class methods for the duration of a block and put the originals back.
    #
    # Minitest 6 ships no `Object#stub`, and these two cases need to stand in for a
    # window a transactional test cannot open: two live database connections
    # racing for one row. The replacements are lambdas because the call sites pass
    # their arguments positionally and keyword arguments alike, and the originals
    # are restored in an `ensure` so a failure inside the block cannot leave the
    # model permanently patched for the rest of the process — which matters, since
    # these tests run in the same process as every other `Draft` test.
    def with_stubbed_class_methods(klass, replacements)
      originals = replacements.keys.to_h { |name| [ name, klass.method(name) ] }

      replacements.each { |name, replacement| klass.define_singleton_method(name, &replacement) }
      yield
    ensure
      originals&.each { |name, original| klass.define_singleton_method(name, original) }
    end
end
