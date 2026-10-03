require "test_helper"

# One author's remembered changes, and the two decisions an author can make
# about them.
#
# The request path that *remembers* a change is covered by
# `test/controllers/draft_mutation_test.rb`, across all twenty mutation
# controllers. What is covered here is the other end: that a draft is read as its
# own author's, that applying it writes through the live mutation path rather than
# around it, and that the one failure this must not have — applying twice — is
# impossible rather than merely unlikely.
class DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @user = users(:user_one)
    @character = characters(:character_one)
    sign_in_as(@user)
  end

  # The list
  #
  # `index` and `show` are reads, so they answer `read` access; `apply` and
  # `discard` are writes, so the shared universe policy asks for `write`. Both
  # halves of that are asserted here rather than left to the shared callback's own
  # tests, because this controller is the first one where the two are different
  # actions in the same page.

  test "the list shows this author's drafts in this universe" do
    mine = draft_with(remember_create_payload)
    other_universe = Draft.create!(user: @user, universe: universes(:universe_two))
    other_universe.draft_changes.create!(action: "create", record_type: "Character", payload: { "name" => "Elsewhere" })
    someone_else = Draft.create!(user: users(:user_two), universe: @universe)
    someone_else.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".content-surface .entity-row", count: 1
    assert_select "a[href=?]", universe_draft_path(universe_slug: @universe.slug, id: mine), count: 1
    assert_select ".entity-title", text: "1 remembered change"
    # Somebody else's unfinished work is not published by the universe it is in,
    # and a draft is authorized inside one universe rather than globally.
    assert_select "a[href=?]", universe_draft_path(universe_slug: @universe.slug, id: someone_else), count: 0
    assert_select "a[href=?]", universe_draft_path(universe_slug: universes(:universe_two).slug, id: other_universe),
      count: 0
  end

  test "the draft that can still be acted on is the first one in the list" do
    history = draft_with(remember_create_payload("Applied"), status: "applied")
    open = draft_with(remember_create_payload("Still open"))

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    # Read in the order the page renders them: the actionable draft first, then
    # the history, each newest-first inside its own group.
    assert_equal [ open.id, history.id ], css_select(".entity-row a.btn-outline-secondary").map { |link| link["href"].split("/").last.to_i }
  end

  test "an author with no drafts is told the list is empty" do
    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-state", text: /Nothing is waiting to be applied/
  end

  test "a read-only member reads their own drafts and cannot apply one" do
    # A read level only exists in a private universe: a public one grants every
    # signed-in user write regardless of what a membership row says, which is why
    # the membership in the fixtures cannot express "this contributor may only
    # read".
    private_universe = Universe.create!(owner: @user, name: "Private one", slug: "private-one", private: true)
    membership = UniverseMembership.create!(user: users(:user_two), universe: private_universe,
      access_level: "read")
    theirs = Draft.create!(user: users(:user_two), universe: private_universe)
    theirs.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Not writable", "universe_id" => private_universe.id })
    sign_out
    sign_in_as(users(:user_two))

    get universe_drafts_url(universe_slug: private_universe.slug)

    assert_response :success

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: private_universe.slug, id: theirs)
    end

    assert_response :forbidden
    assert_predicate membership, :read?
    assert_predicate theirs.reload, :draft?
  end

  test "a guest is sent to sign in rather than shown another reader's drafts" do
    draft_with(remember_create_payload)
    sign_out

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_redirected_to new_session_url
  end

  # One draft in detail

  test "the page states what each remembered change would do" do
    target = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload("Remembered create"))

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 2
    # The changes render in the order they were remembered: an update made before a
    # create is listed before it.
    rows = css_select(".draft-change")
    assert_match(/Update/, rows.first.text)
    assert_match(/Renamed by a draft/, rows.first.text)
    assert_match(/Create/, rows.last.text)
    # A change about a record that exists links to that record's own page, built
    # from its own search declaration rather than from a route named per type.
    assert_select ".draft-change a[href=?]", @character.search_url, count: 1
  end

  test "a remembered create is titled by the type it would create, not by a record" do
    target = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change .entity-title", text: "New Character"
    assert_select ".draft-change a", count: 0
  end

  test "a remembered delete says it removes the record and lists no values" do
    target = draft_with(remember_delete_payload(@character))

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 1
    assert_select ".draft-change .entity-description", text: "This change removes the record."
  end

  test "a remembered tag assignment is listed by name rather than by id" do
    tag = character_tags(:character_tag_one)
    target = draft_with(remember_create_payload("Tagged", extra: { "character_tag_ids" => [ tag.id ] }))

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change .entity-description", text: /#{tag.name}/
    refute_includes response.body, tag.id.to_s
  end

  test "the scope column a create carries is plumbing the page does not print" do
    target = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    # `universe_id` is how the change knows where the record goes. The page is
    # already inside that universe, so printing the number would tell the reader
    # nothing; what it does say is the value they actually submitted.
    assert_select ".draft-change .entity-description", text: /Name/
    refute_match(/Universe/, response.body[/<div class="entity-description">.*?<\/div>/m])
  end

  test "a change whose record has since been deleted is still listed, without a link" do
    target = draft_with(remember_update_payload("Renamed by a draft"))
    @character.soft_delete

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 1
    assert_select ".draft-change .entity-description", text: /Renamed by a draft/
    assert_select ".draft-change a", count: 0
  end

  test "another author's draft and another universe's draft are both a 404" do
    theirs = Draft.create!(user: users(:user_two), universe: @universe)
    elsewhere = Draft.create!(user: @user, universe: universes(:universe_two))

    get universe_draft_url(universe_slug: @universe.slug, id: theirs)
    assert_response :not_found

    get universe_draft_url(universe_slug: @universe.slug, id: elsewhere)
    assert_response :not_found

    get universe_draft_url(universe_slug: @universe.slug, id: 0)
    assert_response :not_found
  end

  test "an empty draft states that it remembers nothing" do
    target = draft_with

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".empty-state", text: /This draft remembers no changes/
    assert_select ".draft-change", count: 0
  end

  test "the apply and discard controls are offered only while the draft is open" do
    open = draft_with(remember_create_payload)
    history = draft_with(remember_create_payload("Already applied"), status: "applied")

    get universe_draft_url(universe_slug: @universe.slug, id: open)
    assert_select "form[action=?]", apply_universe_draft_path(universe_slug: @universe.slug, id: open), count: 1
    assert_select "form[action=?]", discard_universe_draft_path(universe_slug: @universe.slug, id: open), count: 1

    get universe_draft_url(universe_slug: @universe.slug, id: history)
    assert_select "form[action=?]", apply_universe_draft_path(universe_slug: @universe.slug, id: history), count: 0
    assert_select "form[action=?]", discard_universe_draft_path(universe_slug: @universe.slug, id: history), count: 0
  end

  # Applying
  #
  # The live mutation path is the point: the same services, the same model
  # validations, the same soft delete. A test that asserted only "the record
  # changed" would pass against a plain `update_columns`, which is exactly the
  # applier ADR 0019 refuses.

  test "applying writes a create, an update, and a delete through the live path" do
    removed = locations(:location_one)
    target = draft_with(
      remember_create_payload,
      remember_update_payload("Renamed by a draft"),
      remember_delete_payload(removed)
    )

    post apply_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: target)
    assert_equal I18n.t("drafts.flash.applied", count: 3), flash[:notice]
    created = Character.find_by(name: "Remembered create")
    assert created.present?, "a remembered create must be written by the apply"
    assert_equal @character.reload.name, "Renamed by a draft"
    assert_predicate removed.reload, :deleted?
    assert_predicate target.reload, :applied?
  end

  test "a created record lands in the ordered collection the live path would place it in" do
    # A Section is story-scoped, hierarchical, and positioned, so a plain `save`
    # would write it with the column default of 0 and leave it inside somebody
    # else's sibling group. `PositionedResourceOrder` is what makes it the last
    # child of its parent.
    section = draft_with(remember_create_payload("A remembered section", "Section",
      { "story_id" => @story.id, "parent_id" => sections(:section_one).id }))
    siblings = sections(:section_one).children.reorder(:position, :id).to_a

    post apply_universe_draft_url(universe_slug: @universe.slug, id: section)

    written = Section.find_by(name: "A remembered section")
    assert written.present?, "the create must be written"
    assert_equal sections(:section_one).id, written.parent_id
    # Appended after the one sibling that was already there, and the group is
    # renumbered so it stays contiguous — which is what the ordering service does
    # and what a plain `save` with the column default of 0 would not.
    assert_equal siblings.size, written.position
    assert_equal (0...siblings.size + 1).to_a, sections(:section_one).children.reorder(:position, :id).pluck(:position)
    assert_equal siblings.map(&:id) + [ written.id ], sections(:section_one).children.reorder(:position, :id).pluck(:id)
  end

  test "a story-scoped create is placed through the story the payload names" do
    other_story = stories(:story_alt)
    scene = draft_with(remember_create_payload("A remembered scene", "Scene", { "story_id" => other_story.id }))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: scene)

    written = Scene.find_by(name: "A remembered scene")
    assert written.present?
    assert_equal other_story, written.story
    # A Scene's narrative order is a flat sequence inside its own story, so the
    # scene joins the end of that story's sequence and is numbered against it —
    # not against the story the draft's page happens to be sitting in.
    assert_equal other_story.scenes.count - 1, written.position
    assert_equal (0...other_story.scenes.count).to_a, other_story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "a change whose record has moved since it was remembered is reported rather than written" do
    moved = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload)
    change = moved.draft_changes.first
    # Somebody else saved the same record after the change was remembered, which
    # is what `base_version` exists to notice.
    @character.update!(description: "Changed by somebody else")
    assert VersionStamp.changed?(@character, change.base_version)

    post apply_universe_draft_url(universe_slug: @universe.slug, id: moved)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 1, skipped: 1), flash[:notice]
    assert_not_equal "Renamed by a draft", @character.reload.name,
      "a change remembered against an older version must not overwrite the newer one"
    assert Character.find_by(name: "Remembered create").present?,
      "the rest of the draft is still written: one unappliable change does not block the others"
    assert_predicate moved.reload, :applied?
  end

  test "a change the universe refuses is reported rather than half-written" do
    # The remembering path does not validate (ADR 0020), so a create the live path
    # would refuse is remembered and refused here, at the point where the model's
    # own validations are authoritative.
    refused = draft_with(remember_create_payload(""))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: refused)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 0, skipped: 1), flash[:notice]
    assert_equal 0, Character.where(name: "").count
    assert_predicate refused.reload, :applied?
  end

  test "a change whose record has been deleted since is reported rather than written" do
    gone = draft_with(remember_delete_payload(@character))
    @character.soft_delete

    post apply_universe_draft_url(universe_slug: @universe.slug, id: gone)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 0, skipped: 1), flash[:notice]
    assert_predicate gone.reload, :applied?
  end

  test "a create that cannot be placed in this universe is reported rather than written across it" do
    # The scope column is stored data read back later, and it is resolved rather
    # than trusted: a story belonging to another universe is not a scope here.
    foreign = draft_with(remember_create_payload("Out of place", "Character",
      { "universe_id" => universes(:universe_two).id }))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: foreign)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 0, skipped: 1), flash[:notice]
    assert_nil universes(:universe_two).characters.find_by(name: "Out of place"),
      "a create must never be written into a universe the request did not authorize"
  end

  test "applying a draft twice is refused rather than writing a second copy" do
    target = draft_with(remember_create_payload)

    post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    assert_response :see_other

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    end

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: target)
    assert_equal I18n.t("drafts.flash.closed"), flash[:alert]
    assert_equal 1, Character.where(name: "Remembered create").count
  end

  test "a discarded draft cannot be applied afterwards" do
    target = draft_with(remember_create_payload)

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    end

    assert_equal I18n.t("drafts.flash.closed"), flash[:alert]
  end

  # Discarding

  test "discarding closes the draft and keeps the changes it remembered" do
    target = draft_with(remember_create_payload)

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_redirected_to universe_drafts_url(universe_slug: @universe.slug)
    assert_equal I18n.t("drafts.flash.discarded"), flash[:notice]
    assert_predicate target.reload, :discarded?
    # A remembered change is append-only, so rejecting the draft moves the draft's
    # status rather than deleting what it said. The draft's page still lists it.
    assert_equal 1, target.draft_changes.count

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 1
  end

  test "discarding a draft that is already applied changes nothing" do
    target = draft_with(remember_create_payload, status: "applied")

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_equal I18n.t("drafts.flash.closed"), flash[:alert]
    assert_predicate target.reload, :applied?
  end

  test "another author's draft cannot be applied or discarded" do
    theirs = Draft.create!(user: users(:user_two), universe: @universe)
    theirs.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: theirs)
      post discard_universe_draft_url(universe_slug: @universe.slug, id: theirs)
    end

    assert_response :not_found
    assert_predicate theirs.reload, :draft?
  end

  # The page has to be reachable. An editor who is told their change was
  # remembered and cannot then find it has no way to apply or throw it away, so
  # the right sidebar offers it wherever a draft can exist.

  test "the sidebar offers pending changes only where a draft can exist" do
    get universe_url(@universe)
    assert_select "aside.right-sidebar a[href=?]", universe_drafts_path(universe_slug: @universe.slug),
      { count: 0 }, "a direct universe never opens a draft, so the link would lead nowhere"

    @universe.update!(collaboration_mode: "wikipedia")

    get universe_url(@universe)
    assert_select "aside.right-sidebar a[href=?]", universe_drafts_path(universe_slug: @universe.slug), count: 1

    sign_out
    get universe_url(@universe)
    assert_select "aside.right-sidebar a[href=?]", universe_drafts_path(universe_slug: @universe.slug),
      { count: 0 }, "a draft belongs to a person, and a visitor has none"
  end

  private
    def draft_with(*changes, status: "draft")
      Draft.create!(user: @user, universe: @universe, status: status).tap do |draft|
        changes.each { |change| draft.draft_changes.create!(change) }
      end
    end

    # The remembered attributes a controller would have submitted: the values, plus
    # the one column that places the record in its scope, which
    # `draft_mutation_test.rb` asserts for all twenty controllers.
    def remember_create_payload(name = "Remembered create", record_type = "Character",
      scope = { "universe_id" => @universe.id }, extra: {})
      { action: "create", record_type: record_type, record_id: nil, base_version: nil,
        payload: scope.merge("name" => name).merge(extra) }
    end

    def remember_update_payload(name, record = @character)
      { action: "update", record_type: record.class.name, record_id: record.id,
        base_version: DraftChange.capture_base_version(record), payload: { "name" => name } }
    end

    def remember_delete_payload(record)
      { action: "delete", record_type: record.class.name, record_id: record.id,
        base_version: DraftChange.capture_base_version(record), payload: nil }
    end
end
