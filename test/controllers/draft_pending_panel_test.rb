require "test_helper"

# The reader's pending work, in the right sidebar.
#
# The sidebar already led with a **Pending changes** entry (ADR 0021), and this is
# what sits above it: the same facts the drafts page reports, readable from every
# page of the universe. Three things are worth pinning here and nowhere else —
#
# - **it renders at zero as well as at any count**, because the entry is also how a
#   reader with nothing pending reaches the drafts list's history;
# - **it renders only where a draft can exist**, so a `direct` universe and a guest
#   pay nothing and are shown nothing;
# - **it is bounded**, because each row resolves the record its change names and
#   this partial is rendered on every page of the universe — the unbounded-per-row
#   read recorded as finding 66, widened from one page to all of them.
class DraftPendingPanelTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
    @draft = Draft.open_for!(@user, @universe)
  end

  test "an empty draft still renders the panel and the way into the drafts page" do
    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-panel .draft-pending-summary",
      text: I18n.t("drafts.pending.count", count: 0)
    assert_select ".draft-pending-panel .draft-pending-more", text: I18n.t("drafts.pending.panel.empty")
    # The entry is not a control that appears with a count: it is also how a reader
    # reaches the history the drafts list shows.
    assert_select ".sidebar-list > li.draft-pending-panel + li a[href=?]",
      universe_drafts_path(universe_slug: @universe.slug), count: 1
  end

  test "the panel names each remembered change and its record" do
    character = characters(:character_one)
    remember_create("Character", "name" => "Ariadne")
    remember_edit(character, "name" => "Lysander")
    remember_delete(characters(:character_two))

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-panel .draft-pending-summary",
      text: I18n.t("drafts.pending.count", count: 3)

    assert_select ".draft-pending-change", count: 3
    assert_select ".draft-pending-change", text: /^#{Regexp.escape(I18n.t("drafts.actions.create"))}\b/, count: 1
    assert_select ".draft-pending-change", text: /Character one/, count: 1
    assert_select ".draft-pending-change", text: /Character two/, count: 1
  end

  test "a create's row is titled by the type it would create" do
    # A remembered create names no record, so the panel has to say what kind of
    # record it would make — the same sentence the draft's own page uses, because
    # a reader comparing the two must not be told two different things.
    remember_create("Character", "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-change", text: /^#{Regexp.escape(I18n.t("drafts.actions.create"))}\b/, count: 1
    assert_includes css_select(".draft-pending-change").first.text,
      I18n.t("drafts.show.new_record", kind: I18n.t("searches.kinds.character"))
  end

  test "the panel lists a bounded slice and counts the rest" do
    (DraftPreview::PANEL_LIMIT + 2).times { |index| remember_create("Character", "name" => "Character #{index}") }

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-change", count: DraftPreview::PANEL_LIMIT
    assert_select ".draft-pending-panel .draft-pending-more",
      text: I18n.t("drafts.pending.panel.more", count: 2)
  end

  test "a universe that writes changes straight through has no panel" do
    remember_create("Character", "name" => "Ariadne")
    @universe.update!(collaboration_mode: "direct")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-panel", count: 0
  end

  test "a guest has no panel" do
    remember_create("Character", "name" => "Ariadne")
    sign_out

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-panel", count: 0
  end

  test "another reader's pending work is not in the panel" do
    their_draft = Draft.open_for!(users(:user_two), @universe)
    their_draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-panel .draft-pending-summary",
      text: I18n.t("drafts.pending.count", count: 0)
    assert_select ".draft-pending-change", count: 0
  end

  test "the panel follows the draft's status" do
    remember_create("Character", "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)
    assert_select ".draft-pending-change", count: 1

    # An applied draft is history, and a change's pendingness is the draft's status
    # and nothing else — so the panel empties when the draft closes.
    @draft.update!(status: "discarded")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-change", count: 0
    assert_select ".draft-pending-panel", count: 1
  end

  test "the panel is on a page that has no list of its own" do
    # It belongs to the sidebar rather than to any one workspace, so it has to be
    # there on the pages a reader lands on while remembering things: the universe
    # page, the drafts page, and a record's own details page.
    remember_create("Character", "name" => "Ariadne")
    expected = I18n.t("drafts.pending.count", count: 1)

    [
      universe_path(universe_slug: @universe.slug),
      universe_drafts_path(universe_slug: @universe.slug),
      universe_character_path(universe_slug: @universe.slug, id: characters(:character_one).id)
    ].each do |path|
      get path

      assert_response :success
      assert_select ".draft-pending-panel .draft-pending-summary", text: expected,
        message: "#{path} must show the panel too"
    end
  end

  private
    def remember_create(type, payload = {})
      @draft.draft_changes.create!(action: "create", record_type: type,
        payload: { "universe_id" => @universe.id }.merge(payload.stringify_keys))
    end

    def remember_edit(record, payload = {})
      @draft.draft_changes.create!(action: "update", record_type: record.class.name,
        record_id: record.id, payload: payload.stringify_keys,
        base_version: DraftChange.capture_base_version(record))
    end

    def remember_delete(record)
      @draft.draft_changes.create!(action: "delete", record_type: record.class.name,
        record_id: record.id, base_version: DraftChange.capture_base_version(record))
    end
end
