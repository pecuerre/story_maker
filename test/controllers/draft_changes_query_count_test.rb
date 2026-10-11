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

  test "a list page costs the same for one pending row and for four" do
    # **The guard on resolving a pending row's tags.** Assigning the submitted tag
    # *records* rather than their ids is what keeps this flat: an id writer leaves
    # the association unloaded, so four pending rows would ask the tag table once
    # each when their badges rendered — which is finding 66's per-row read, back on
    # a surface that had stopped paying it. Every remembered create here names tags,
    # so the rows are the expensive shape rather than a convenient one.
    path = universe_characters_path(universe_slug: @universe.slug)

    remember_pending_creates(1)
    get path
    assert_equal 1, css_select(".draft-pending-row").size
    with_one = count_queries { get path }

    remember_pending_creates(3)
    get path
    assert_equal 4, css_select(".draft-pending-row").size
    with_four = count_queries { get path }

    assert_response :success
    assert_equal with_one, with_four,
      "three more pending rows and three more queries is the per-row tag read finding 66 records"
  end

  test "naming a badged row's pending fields costs no query" do
    # **The guard on what a badge's tooltip may say.** Naming the fields a pending
    # edit would write means reading each change's payload, which the backlog item
    # that asked for it priced as "a per-row read". It is not: `DraftPreview` builds
    # the state, the count, and the payload keys in the **same single pass** over
    # `draft.draft_changes`, and those rows are already loaded with their payloads,
    # so the naming is arithmetic over data the request has. The shape here is the
    # expensive one — one record, many remembered edits, each naming a different
    # column plus a tag list — so a per-row payload read would show up here rather
    # than on a convenient single change.
    path = universe_characters_path(universe_slug: @universe.slug)
    character = characters(:character_one)

    remember_edits(character, 1)
    get path
    assert_equal 1, css_select(".draft-pending-badge").size
    with_one = count_queries { get path }

    remember_edits(character, 5)
    get path
    assert_equal 1, css_select(".draft-pending-badge").size
    with_six = count_queries { get path }

    assert_response :success
    assert_equal with_one, with_six,
      "five more remembered edits and five more queries is the per-row payload read the tooltip must not pay"
  end

  test "a pending row carrying no tags adds no query either" do
    # The other shape, and a different path through `DraftPreview`: a payload with no
    # tag key at all never assigns an association, so the badge reads an untouched
    # one. The tagged case above cannot see that path, and a new record whose
    # association is read for the first time is exactly where a per-row query would
    # hide.
    path = universe_characters_path(universe_slug: @universe.slug)

    1.times { remember_untagged_pending_create }
    get path
    assert_equal 1, css_select(".draft-pending-row").size
    with_one = count_queries { get path }

    3.times { remember_untagged_pending_create }
    get path
    assert_equal 4, css_select(".draft-pending-row").size
    with_four = count_queries { get path }

    assert_response :success
    assert_equal with_one, with_four
  end

  test "naming the scope a create would be written under costs no query per row" do
    # **The guard on resolving a scope column.** The drafts page prints the story or
    # scene a remembered create would be written under, which is a lookup by id — the
    # same shape as the tag read above, and the same place a per-row query would
    # hide. The changes here are story-scoped rather than universe-scoped precisely
    # because that is the case that has an owner to resolve: a Character's
    # `universe_id` names nothing the reader cannot already see, so a universe-scoped
    # draft would pass this test without ever asking.
    path = universe_draft_path(universe_slug: @universe.slug, id: @draft)

    remember_scene_creates(1)
    get path
    assert_equal 1, css_select(".draft-change .entity-description").text.scan("Story One").size
    with_one = count_queries { get path }

    remember_scene_creates(4)
    get path
    assert_equal 5, css_select(".draft-change .entity-description").text.scan("Story One").size
    with_five = count_queries { get path }

    assert_response :success
    assert_equal with_one, with_five,
      "four more story-scoped changes and four more story queries is the per-row scope read this must not pay"
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

  test "the universe's change history costs the same for a short history and a long one" do
    # **The fifth surface drawing these rows, and the one where a per-row read would
    # cost the most.** Every other case draws one draft; this one draws every closed
    # draft in a universe, so a missing `changes` local is not one extra query per row
    # but one per row on the largest list in the collaboration workflow. The `changes`
    # local is handed the whole page's collection rather than each day's, which is what
    # makes it batched.
    @universe.update!(collaboration_mode: "wikipedia")
    remember_changes(1)
    close_as_applied(@draft)
    path = universe_history_path(universe_slug: @universe.slug)

    get path
    assert_equal 2, rendered_changes
    with_two = count_queries { get path }

    # A second closed draft rather than more changes in the first: an author has one
    # draft per universe at a time, and a closed one can be given more changes only
    # before it runs. A second author is what a real history is made of.
    later = Draft.create!(user: users(:user_two), universe: @universe)
    remember_changes(4, later)
    close_as_applied(later)

    get path
    assert_equal 10, rendered_changes
    with_ten = count_queries { get path }

    assert_response :success
    assert_equal with_two, with_ten,
      "eight more changes and one more query each is the per-row read finding 66 records"
  end

  test "the collaborators list costs the same for one collaborator and for five" do
    # **The list aggregates over people rather than over rows**, so its cost grows with
    # the number of *collaborators*, not the number of runs: two grouped counts and one
    # load of the names. Resolving an author per row would be a query per collaborator
    # instead of one for all of them, which is what `Collaborators#all` exists to avoid.
    @universe.update!(collaboration_mode: "wikipedia")
    path = universe_collaborators_path(universe_slug: @universe.slug)

    close_as_applied(closed_draft_for(@user))
    get path
    assert_equal 1, css_select(".collaborator-row").size
    with_one = count_queries { get path }

    4.times do |index|
      author = User.create!(name: "User #{index}", email_address: "extra-#{index}@example.com",
        password: "password")
      close_as_applied(closed_draft_for(author))
    end

    get path
    assert_equal 5, css_select(".collaborator-row").size
    with_five = count_queries { get path }

    assert_response :success
    assert_equal with_one, with_five,
      "four more collaborators and four more queries is the per-row read finding 66 records"
  end

  private
    # A closed draft with one remembered create, for the collaborators list's per-author
    # setup: it only needs a run to exist, not a run with a long payload.
    #
    # **Any open draft for this author is closed first**, because the partial unique
    # index on `[user_id, universe_id]` covers the open statuses: a second open draft
    # for one author is a refused write rather than a second run.
    def closed_draft_for(author)
      existing = Draft.open_for(author, @universe)
      close_as_applied(existing) if existing
      draft = Draft.create!(user: author, universe: @universe)
      remember_changes(1, draft)
      draft
    end

    # Close a draft the way the applier does, because that is what writes `closed_at`
    # and the run's tally — and the history page requires both.
    def close_as_applied(draft)
      draft.reload
      draft.draft_changes.each do |change|
        next if change.outcome.present?

        DraftChangeOutcome.create!(draft: draft, draft_change: change, state: "written")
      end
      draft.update!(status: "applied", closed_at: Time.current,
        applied_count: draft.draft_changes.count, skipped_count: 0, kept_count: 0)
    end

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

    # Remembered creates that each name a tag, which is the shape a pending row with
    # badges costs the most to render.
    def remember_pending_creates(count)
      count.times do |index|
        tag = @universe.character_tags.create!(name: "Pending tag #{index}",
          position: @universe.character_tags.count + 1)
        @draft.draft_changes.create!(action: "create", record_type: "Character",
          payload: { "universe_id" => @universe.id, "name" => "Pending #{index}",
                     "character_tag_ids" => [ tag.id ] })
      end
      @draft.reload
    end

    # **Scene creates rather than Character creates**, because a Scene's scope column
    # names a story that has to be resolved while a Character's names the universe
    # the page is already inside. Every one of them names the same story, so a single
    # owner class covers the lot and the count is a difference rather than a total:
    # five rows must not cost five story lookups.
    def remember_scene_creates(count)
      count.times do |index|
        @draft.draft_changes.create!(action: "create", record_type: "Scene",
          payload: { "story_id" => stories(:story_one).id, "name" => "Pending scene #{index}" })
      end
      @draft.reload
    end

    # A remembered create naming no tag list, so the row's badge reads an
    # association nothing was ever assigned to.
    def remember_untagged_pending_create
      @draft.draft_changes.create!(action: "create", record_type: "Character",
        payload: { "universe_id" => @universe.id, "name" => "Untagged pending" })
      @draft.reload
    end

    # Remembered edits **to one record**, each naming a different column and a tag
    # list, so the badge on a single row has the most to say and the least to ask.
    def remember_edits(character, count)
      count.times do |index|
        tag = @universe.character_tags.create!(name: "Edited tag #{index}",
          position: @universe.character_tags.count + 1)
        @draft.draft_changes.create!(action: "update", record_type: "Character", record_id: character.id,
          base_version: DraftChange.capture_base_version(character),
          payload: { "name" => "Renamed #{index}", "character_tag_ids" => [ tag.id ] })
      end
      @draft.reload
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
