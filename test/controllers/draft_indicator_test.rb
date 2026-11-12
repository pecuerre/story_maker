require "test_helper"

# The reader's own pending work, in the top bar.
#
# The right sidebar already carried it (`draft_pending_panel_test.rb`), but that
# column is a drawer below `xl`: a reader on a tablet has to open the tools panel
# to learn whether anything is waiting. This indicator is the same fact in the one
# place every page has, so what matters here is that it says the same thing, in
# the same words, under the same gates — and that it is there at zero as well as
# at any count.
class DraftIndicatorTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
    @draft = Draft.open_for!(@user, @universe)
  end

  test "the top bar states the count and leads to the drafts list" do
    2.times { |index| remember_create("Character", "name" => "Remembered #{index}") }

    # A Story page, because the whole point of the top-bar placement is a page
    # whose own header says nothing about pending work.
    get universe_story_path(universe_slug: @universe.slug, id: stories(:story_one).id)

    assert_response :success
    assert_select "nav.navbar a.draft-indicator[href=?]",
      universe_drafts_path(universe_slug: @universe.slug), count: 1
    assert_select ".draft-indicator .draft-indicator-count", text: "2"
    assert_select ".draft-indicator[title=?]", I18n.t("drafts.pending.count", count: 2)
    assert_select ".draft-indicator[aria-label=?]",
      "#{I18n.t("drafts.indicator.label")}: #{I18n.t("drafts.pending.count", count: 2)}"
  end

  test "it renders at zero without a count badge" do
    get universe_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav.navbar .draft-indicator", count: 1
    assert_select ".draft-indicator .draft-indicator-count", count: 0
    # The words are the ones the sidebar panel and the universe page use, so the
    # three surfaces cannot describe one draft in three ways.
    assert_select ".draft-indicator[title=?]", I18n.t("drafts.pending.count", count: 0)
  end

  test "it marks the drafts page current" do
    get universe_drafts_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-indicator.active[aria-current=?]", "page"
  end

  test "a direct universe and a guest get no indicator" do
    remember_create("Character", "name" => "Ariadne")

    @universe.update!(collaboration_mode: "direct")
    get universe_path(universe_slug: @universe.slug)
    assert_select ".draft-indicator", count: 0,
      message: "a direct universe never opens a draft, so there is no state to state"

    @universe.update!(collaboration_mode: "wikipedia")
    sign_out
    get universe_path(universe_slug: @universe.slug)
    assert_select ".draft-indicator", count: 0,
      message: "a draft belongs to a person, and a visitor has none"
  end

  test "the count is on the universe page before any editing session starts" do
    # The session is a mode, not a gate (ADR 0022), and stopping one leaves the
    # draft open — so a count that appeared only while the session was on would
    # hide the work from the author who came back to it.
    remember_create("Character", "name" => "Ariadne")

    get universe_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".page-actions a[href=?]", universe_drafts_path(universe_slug: @universe.slug),
      text: I18n.t("drafts.pending.count", count: 1)
    assert_select ".page-actions button", text: I18n.t("drafts.editing.start")
  end

  private
    def remember_create(type, payload = {})
      @draft.draft_changes.create!(action: "create", record_type: type,
        payload: { "universe_id" => @universe.id }.merge(payload.stringify_keys))
    end
end
