require "test_helper"

# A page that draws a draft costs a fixed number of queries, not one per row.
#
# This is the guard on finding 66, which recorded the cost as a note rather than as a
# test. Every list page in this application preloads through a grouped query, and these
# three were the two places that did not: a draft's page resolved the record behind each
# change one row at a time (`DraftChange#resolved_record`), the tag ids in each payload
# one at a time (`DraftsHelper#association_names`), and each change's outcome one at a time
# (an `includes` whose return value was discarded, so the preload attached to instances
# nobody rendered). The sidebar's pending panel paid the same price **on every page of
# the universe**, which is what made it the expensive half.
#
# **The assertion is a difference, not a number.** Each case renders the page with a short
# draft and again with a long one and requires the two counts to be equal: the chrome
# around the rows — session, universe, sidebar counts, notifications — is identical in
# both, so a fixed total would be a number that has to be rewritten every time the layout
# gains a query, and a per-row read would still pass it. Eight more changes and not one
# more query is the property worth holding.
#
# The rows themselves are built to be the expensive shape: a remembered **create** naming
# tag ids (which used to cost a `WHERE id IS NULL` as well as a tag query each) and a
# remembered **update** naming a record, so both halves of the reader are exercised.
class DraftChangesQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
    @draft = Draft.open_for!(@user, @universe)
  end

  test "the draft's own page costs the same for a short draft and a long one" do
    path = universe_draft_path(universe_slug: @universe.slug, id: @draft)

    remember_changes(1)
    get path
    assert_equal 2, rendered_changes
    with_two = count_queries { get path }

    remember_changes(4)
    get path
    assert_equal 10, rendered_changes
    with_ten = count_queries { get path }

    assert_response :success
    assert_equal with_two, with_ten,
      "eight more changes and one more query each is the per-row read finding 66 records"
  end

  test "the pending panel costs the same however long the draft is" do
    # **Every page of the universe renders this**, which is why it is the half of the
    # finding that mattered most: a bounded five rows is still five queries on every
    # page, and the whole layout carries it.
    path = universe_characters_path(universe_slug: @universe.slug)

    remember_changes(1)
    get path
    with_two = count_queries { get path }

    remember_changes(4)
    get path
    with_ten = count_queries { get path }

    assert_response :success
    assert_equal with_two, with_ten
  end

  test "a reviewer's page costs the same for a short submission and a long one" do
    @universe.update!(collaboration_mode: "github")
    sign_out
    sign_in_as(@universe.owner)
    draft = Draft.create!(user: users(:user_two), universe: @universe)
    remember_changes(1, draft)
    request = draft.submit!
    path = universe_review_request_path(universe_slug: @universe.slug, id: request)

    get path
    with_two = count_queries { get path }

    remember_changes(4, draft)
    get path
    with_ten = count_queries { get path }

    assert_response :success
    assert_equal with_two, with_ten
  end

  test "a closed draft's outcomes are read once rather than once per row" do
    # **An absolute count here rather than the difference the other three cases use.**
    # `draft_change_outcomes` is one table with one query against it, so "exactly one" is
    # a fact about the preload and not a number that moves with the layout; and the two
    # rows it would have to beat cannot be built in one test — an outcome is stored per
    # change under a unique index, and an author has one draft per universe, so a draft
    # that has run cannot be given eight more changes and run again.
    remember_changes(1)
    @draft.draft_changes.reload.each do |change|
      DraftChangeOutcome.create!(draft: @draft, draft_change: change, state: "written")
    end
    remember_changes(4)
    @draft.draft_changes.reload.each do |change|
      next if change.outcome.present?

      DraftChangeOutcome.create!(draft: @draft, draft_change: change, state: "written")
    end
    @draft.update!(status: "applied", closed_at: Time.current,
      applied_count: @draft.draft_changes.count, skipped_count: 0, kept_count: 0)

    path = universe_draft_path(universe_slug: @universe.slug, id: @draft)
    get path
    assert_response :success
    assert_equal 10, rendered_outcomes

    assert_equal 1, count_queries(/FROM "draft_change_outcomes"/) { get path },
      "one outcome query is the whole point: the preload used to be discarded, so every " \
      "row resolved its own"
  end

  test "the reviewer's conflict page batches the remembered values too" do
    # The page that stops an approval, which is the fourth surface drawing these rows and
    # the one most easily forgotten: a missing `changes` local renders exactly the same
    # HTML and costs one query per row, so only a count can see it. It is reached by
    # **posting** the approval rather than by a `GET`, because this page is an approval
    # waiting to be answered — the same shape as an author's own apply (ADR 0021).
    @universe.update!(collaboration_mode: "github")
    sign_out
    sign_in_as(@universe.owner)
    draft = Draft.create!(user: users(:user_two), universe: @universe)
    remember_changes(1, draft)
    request = draft.submit!
    conflict_the_draft_with(draft)
    path = approve_universe_review_request_path(universe_slug: @universe.slug, id: request)

    post path
    assert_response :unprocessable_content
    assert_equal 1, css_select(".draft-conflict").size
    with_one = count_queries(/FROM "character_tags"/) { post path }

    3.times { remember_changes(1, draft) }
    conflict_the_draft_with(draft)

    post path
    assert_equal 4, css_select(".draft-conflict").size
    with_four = count_queries(/FROM "character_tags"/) { post path }

    # **One batched read for every row's remembered values, plus one live association
    # read per row** — and the second half is the floor, not an oversight: the "theirs"
    # column asks what is stored now, which is in no remembered payload, and the HABTM
    # associations carry an instance-dependent scope and cannot be eager loaded. The
    # remembered half is what this pins: unbatched, it would be one query per tag id per
    # row, so four conflicts would read sixteen rather than four.
    assert_equal 2, with_one
    assert_equal 5, with_four
  end

  private
    # Every remembered edit in this draft becomes a conflict by moving its record after
    # the change was remembered against it, which is what `DraftConflictDetector` asks
    # about. The submission was made before that, so the reviewer is being asked about a
    # draft that moved under them — the journey `drafts/conflicts` exists for.
    def conflict_the_draft_with(draft)
      draft.draft_changes.reload.each do |change|
        next if change.creating?

        record = change.resolved_record
        record.update!(name: "#{record.name} moved")
      end
    end

    def remember_changes(count, draft = @draft)
      count.times do |index|
        tag = @universe.character_tags.create!(name: "Tag #{index}", position: @universe.character_tags.count + 1)
        draft.draft_changes.create!(action: "create", record_type: "Character",
          payload: { "universe_id" => @universe.id, "name" => "Created #{index}", "character_tag_ids" => [ tag.id ] })
        character = characters(:character_one)
        draft.draft_changes.create!(action: "update", record_type: "Character", record_id: character.id,
          base_version: DraftChange.capture_base_version(character),
          payload: { "name" => "Renamed #{index}", "character_tag_ids" => [ tag.id ] })
      end
      draft.reload
    end

    # A count, not a list — and the count is what the assertions compare, so these two
    # return a number on purpose. `.draft-change` rather than a longer selector: the
    # sidebar panel's rows are `.draft-pending-change`, a different class token, so a
    # page's own changes are the only matches.
    def rendered_changes
      css_select(".draft-change").size
    end

    def rendered_outcomes
      css_select(".draft-change-outcome").size
    end
end
