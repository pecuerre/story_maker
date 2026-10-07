require "test_helper"

# What a remembered change looks like on the three surfaces that are not list
# workspaces, which is where backlog item 27 pointed once finding 69 was verified.
#
# Each surface was a separate question with a separate answer, so each is stated
# here rather than folded into the list sweep:
#
# * **A record's own details page carries the badge.** A reader who follows a
#   pending row's name used to arrive at a page that said nothing about the work
#   waiting, and "Details is deliberately a clean record of what is stored" was the
#   other possible answer — rejected because the badge makes no claim about the
#   values: the page still shows what is stored, exactly as ADR 0023 requires.
# * **A tag's list of the records carrying it lists pending rows too.** Once a
#   pending row carries its tags, the tag page is a list workspace like any other:
#   it is where a reader asks which records carry a tag.
# * **The global search dropdown does not.** It indexes stored documents, and a
#   remembered create has none; the file records that as the decision rather than
#   the code recording it as an omission.
class PendingChangeSurfacesTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
    @draft = Draft.open_for!(@user, @universe)
  end

  # The details page

  test "a record's own details page badges a remembered edit" do
    character = characters(:character_one)
    remember_update(character, "name" => "Ariadne")

    get universe_character_path(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_select ".draft-pending-badge", text: I18n.t("drafts.pending.states.edit")
  end

  test "a record's own details page badges a remembered deletion" do
    character = characters(:character_one)
    @draft.draft_changes.create!(action: "delete", record_type: "Character",
      record_id: character.id, base_version: DraftChange.capture_base_version(character))

    get universe_character_path(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_select ".draft-pending-badge", text: I18n.t("drafts.pending.states.deletion")
  end

  test "the details page still shows the stored values behind the badge" do
    # The badge is a claim about the draft, not a rewrite of the record: ADR 0023
    # refused showing unapplied values on a pending row, and the same rule has to
    # hold on the page a reader lands on from that row.
    character = characters(:character_one)
    stored_name = character.name
    remember_update(character, "name" => "Ariadne")

    get universe_character_path(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_select "h1", text: stored_name
    assert_select ".draft-pending-badge", text: I18n.t("drafts.pending.states.edit")
  end

  test "a record with nothing pending carries no badge on its own page" do
    get universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))

    assert_response :success
    assert_select ".draft-pending-badge", count: 0
  end

  test "a tag's own details page badges a remembered edit on it" do
    # The details partial is shared by all eighteen models, so this is the same code
    # path as the Character above — asserted on a tag because a taxonomy tag is the
    # record type a pending row also appears for.
    tag = character_tags(:character_tag_one)
    remember_update(tag, "name" => "Protagonist")

    get universe_character_tag_path(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_select ".draft-pending-badge", text: I18n.t("drafts.pending.states.edit")
  end

  test "another reader's draft badges nothing on a details page" do
    # The badge is drawn from this reader's own preview, which is the same
    # authorization ADR 0021 recorded for the drafts page: somebody else's pending
    # work is not an oracle here either.
    character = characters(:character_one)
    other = Draft.create!(user: users(:user_two), universe: @universe)
    other.draft_changes.create!(action: "update", record_type: "Character",
      record_id: character.id, base_version: DraftChange.capture_base_version(character),
      payload: { "name" => "Somebody else's name" })

    get universe_character_path(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_select ".draft-pending-badge", count: 0
  end

  # A tag's list of the records carrying it

  test "a tag's record list includes a remembered create carrying that tag" do
    tag = character_tags(:character_tag_one)
    remember_create("Character", "name" => "Pending protagonist",
      "character_tag_ids" => [ tag.id ])

    get universe_character_tag_path(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Pending protagonist"
  end

  test "a tag's record list leaves out a remembered create carrying another tag" do
    # The negative half, and the one that makes the positive case mean anything: a
    # pending row is filed under the tags it actually carries, not under every tag
    # page in the universe.
    remember_create("Character", "name" => "Pending protagonist",
      "character_tag_ids" => [ character_tags(:character_tag_one).id ])

    get universe_character_tag_path(universe_slug: @universe.slug, id: character_tags(:character_tag_two))

    assert_response :success
    assert_select ".draft-pending-row", count: 0
  end

  test "a tag with no stored records does not say it is empty when a pending row carries it" do
    # The same rule every list workspace follows, and the reason `detail_section`
    # reads a pending count separately from the badge: a page that says "no
    # characters here" above a row carrying a name is two answers to one question.
    empty_tag = @universe.character_tags.create!(name: "Unused", position: @universe.character_tags.count + 1)
    remember_create("Character", "name" => "Pending protagonist",
      "character_tag_ids" => [ empty_tag.id ])

    get universe_character_tag_path(universe_slug: @universe.slug, id: empty_tag)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Pending protagonist"
    assert_select ".empty-state", count: 0
  end

  test "a tag's record count badge counts stored records only" do
    # The other half of the same rule: the badge is a fact about what exists, so a
    # remembered create must not be added to it even though its row is on the page.
    tag = character_tags(:character_tag_one)
    stored = tag.tagged_records_including_descendants.size
    remember_create("Character", "name" => "Pending protagonist", "character_tag_ids" => [ tag.id ])

    get universe_character_tag_path(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_select ".detail-section .badge", text: /^#{stored}$/
    assert_select ".draft-pending-row", count: 1
  end

  test "a grouping tag files a pending row under the child tag it carries" do
    # A grouping tag has no records of its own — it lists one section per child —
    # so a pending row has to be asked per child. Filing it under the parent, or
    # under every child, would be a second answer to which tag a record carries.
    parent = @universe.character_tags.create!(name: "Roles", taggable: false, position: 90)
    child = @universe.character_tags.create!(name: "Protagonist", parent: parent, position: 91)
    remember_create("Character", "name" => "Pending protagonist", "character_tag_ids" => [ child.id ])

    get universe_character_tag_path(universe_slug: @universe.slug, id: parent)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Pending protagonist"
  end

  test "a pending row on a tag's page is read rather than linked" do
    # There is no id to build a path from, exactly as in a list workspace.
    tag = character_tags(:character_tag_one)
    remember_create("Character", "name" => "Pending protagonist", "character_tag_ids" => [ tag.id ])

    get universe_character_tag_path(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_select ".draft-pending-row a", count: 0
  end

  # The search dropdown

  test "the search dropdown is left clean of pending rows" do
    # Not a missing feature: search indexes stored documents, and a remembered
    # create has none, so a pending row there would be a result with nothing to
    # open. The decision is recorded in `docs/features/search.md`; this holds the
    # code to it, so a future change that indexes unsaved records has to decide it
    # deliberately rather than inherit it.
    remember_create("Character", "name" => "Pending protagonist")

    get universe_search_path(universe_slug: @universe.slug), params: { q: "Pending" }

    assert_response :success
    assert_select ".draft-pending-row", count: 0
    assert_select "a", count: 0, text: /Pending protagonist/
  end

  private
    def remember_create(type, payload = {})
      @draft.draft_changes.create!(action: "create", record_type: type,
        payload: { "universe_id" => @universe.id }.merge(payload.stringify_keys))
    end

    def remember_update(record, payload = {})
      @draft.draft_changes.create!(action: "update", record_type: record.class.name,
        record_id: record.id, base_version: DraftChange.capture_base_version(record),
        payload: payload.stringify_keys)
    end
end
