require "test_helper"

class RelationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
    @relation_tag = RelationTag.create!(universe: @universe, name: "Child of")
    sign_in_as(users(:user_one))
  end

  test "should get index with relation options" do
    get universe_relations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Relations"
    assert_includes response.body, @character_one.name
    assert_includes response.body, @relation_tag.name
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_relations_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]",
      universe_characters_path(universe_slug: @universe.slug), text: "Characters"
    assert_select "nav.content-tabs a[href=?]",
      universe_character_tag_path(universe_slug: @universe.slug, id: character_tags(:character_tag_one), from: "workspace"),
      text: "Character tag one"
  end

  test "should create relation and redirect" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: {
          character1_id: @character_one.id,
          character2_id: @character_two.id,
          relation_tag_ids: [ @relation_tag.id ],
          description: "They are family"
        }
      }
    end

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_equal "They are family", Relation.order(:id).last.description
  end

  test "should create a relation without tags" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: {
          character1_id: @character_one.id,
          character2_id: @character_two.id,
          description: "No taxonomy needed"
        }
      }
    end

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_empty Relation.order(:id).last.relation_tags
  end

  test "should update relation and redirect" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two, relation_tags: [ @relation_tag ])

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { description: "Updated description" }
    }

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_equal "Updated description", relation.reload.description
  end

  test "a PATCH and a DELETE answer with see_other, not a 302" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two)

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { description: "Updated" }
    }

    assert_response :see_other

    delete universe_relation_url(universe_slug: @universe.slug, id: relation)

    assert_response :see_other
    assert_predicate relation.reload, :deleted?
  end

  test "the optional name is accepted, offered back, and used as the label" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: {
          name: "Siblings",
          character1_id: @character_one.id,
          character2_id: @character_two.id
        }
      }
    end

    relation = Relation.order(:id).last
    assert_equal "Siblings", relation.name
    # `display_string` and the composite slug both prefer a name when one is set,
    # so a name the editor could not write was a name nothing could display.
    assert_equal "Siblings", relation.display_string
    assert_equal "siblings", relation.slug

    get universe_relations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[name='relation[name]']"
    # The editor for this row is prefilled from the serialized record, so the
    # stored name has to travel on that row's trigger.
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"name":"Siblings"'
  end

  test "a stored name is renamed and cleared through the editor" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two,
      name: "Old name")

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { name: "New name" }
    }

    assert_equal "New name", relation.reload.name

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { name: "" }
    }

    # A blank name clears it rather than being rejected: the field is optional,
    # and the endpoints remain the label.
    assert_nil relation.reload.name
    assert_equal "#{@character_one.name} → #{@character_two.name}", relation.display_string
  end

  test "the datetime editors keep stored seconds" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two,
      from_date: Time.utc(2026, 1, 2, 3, 4, 5), to_date: Time.utc(2027, 1, 2, 3, 4, 6))

    get universe_relations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[type=datetime-local][name='relation[from_date]'][step='1']"
    assert_select "input[type=datetime-local][name='relation[to_date]'][step='1']"
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"from_date":"2026-01-02T03:04:05"'
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"to_date":"2027-01-02T03:04:06"'
  end

  test "a rejected create states the reason and keeps the entered values in the editor" do
    assert_no_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: { character1_id: @character_one.id, character2_id: "", description: "Kept for another try" }
      }
    end

    assert_response :unprocessable_content
    # The reason is stated on the page the author lands on, and again inside the
    # editor they reopen, because this workspace re-renders after a rejection.
    assert_select ".alert-danger[role=alert]", text: /prevented this relation from being saved/
    # The attribute name is named in `activerecord.attributes.relation`, so the
    # message reads "Character 2" rather than Rails' humanized "Character2".
    assert_select ".alert-danger[role=alert] li", text: /Character 2/
    assert_select "[data-modal-form-target='modal'] .alert-danger li", text: /Character 2/
    # The invalid values are serialized into the Add trigger, so reopening the
    # editor does not silently discard the entry.
    assert_select "button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relations_path(universe_slug: @universe.slug), "Kept for another try"
  end

  test "a rejected update prefill reaches only the edited row" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two)
    other = Relation.create!(universe: @universe, character1: @character_two, character2: @character_one, description: "Stored text")

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { character2_id: "", description: "Rejected text" }
    }

    assert_response :unprocessable_content
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relation_path(universe_slug: @universe.slug, id: relation), "Rejected text"
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relation_path(universe_slug: @universe.slug, id: other), "Stored text", count: 1
  end

  # The filter, the sort, and the three empty states. `RelationFilterTest` covers
  # the value object; what only a request can show is the page around it — the
  # canonical URL, what the filter does to rows, and that it survives a re-render.
  test "index renders a search area that narrows, orders, and stays in the URL" do
    Relation.create!(universe: @universe, character1: characters(:character_three),
      character2: @character_one, description: "Raised together")

    get universe_relations_url(universe_slug: @universe.slug, q: "Raised", sort: "created")

    assert_response :success
    assert_select "form[action=?][method=?]", universe_relations_path(universe_slug: @universe.slug), "get" do
      assert_select "input[name=q][value=?]", "Raised"
      assert_select "select[name=sort] option[selected][value=?]", "created"
    end
    assert_select ".relation-filter", text: /Showing 1 relation of 2 relations/
    assert_select ".entity-list .entity-row", count: 1
  end

  test "index finds a relation by the name of one of its endpoint characters" do
    # The label is the two characters, composed rather than stored, so this is
    # the case a `LIKE` on the relation's own columns cannot answer.
    Relation.create!(universe: @universe, character1: characters(:character_three),
      character2: @character_two)

    get universe_relations_url(universe_slug: @universe.slug, q: "Character three")

    assert_response :success
    assert_select ".entity-list .entity-row", count: 1
    assert_select ".entity-list .entity-title", text: "Character three"
    assert_select ".relation-filter", text: /Search: “Character three”/
  end

  test "index filters by a relation tag" do
    Relation.create!(universe: @universe, character1: characters(:character_three),
      character2: @character_one, relation_tags: [ @relation_tag ])

    get universe_relations_url(universe_slug: @universe.slug, relation_tag_id: @relation_tag.id)

    assert_response :success
    assert_select ".entity-list .entity-row", count: 1
    assert_select "select[name=relation_tag_id] option[selected][value=?]", @relation_tag.id
  end

  test "index redirects a form submission to the canonical filter query" do
    get universe_relations_url(universe_slug: @universe.slug, q: "Mentor", relation_tag_id: "", sort: "")

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug, q: "Mentor")
  end

  test "index reports a relation tag it could not use instead of showing an empty list" do
    get universe_relations_url(universe_slug: @universe.slug, relation_tag_id: relation_tags(:relation_tag_three).id)

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not a relation tag of this universe/
    assert_select ".entity-list .entity-row", count: 1
  end

  test "index reports an order this list does not offer and falls back to the default" do
    get universe_relations_url(universe_slug: @universe.slug, sort: "password")

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not one this list offers/
    assert_select "select[name=sort] option[selected][value=?]", RelationFilter::DEFAULT_SORT
  end

  test "index separates a filtered empty result from a universe without relations" do
    get universe_relations_url(universe_slug: @universe.slug, q: "no such relation")

    assert_response :success
    assert_select ".empty-title", text: "No relations match these filters"
    assert_select ".empty-description",
      text: /Universe one has 1 relation, but none of them match the filters above/
    assert_select ".empty-state .badge", text: /Search: “no such relation”/
    assert_select ".empty-state a", text: "Clear filters"
    assert_select ".relation-filter a", text: "Clear filters", count: 0
    assert_select ".empty-state a", text: /Add relation/, count: 0
  end

  test "a guest can filter and sees no mutation control" do
    sign_out

    get universe_relations_url(universe_slug: @universe.slug, q: "Character one")

    assert_response :success
    assert_select ".entity-list .entity-row", count: 1
    assert_select "form[data-controller=modal-form]", count: 0
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select ".relation-filter input[name=q]", minimum: 1
  end

  test "a filter survives a rejected create and comes back on the editor" do
    post universe_relations_url(universe_slug: @universe.slug, q: "Character one"), params: {
      relation: { character1_id: @character_one.id, character2_id: "", description: "Kept for another try" }
    }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert]", text: /prevented this relation from being saved/
    # The filter is still in effect, so the page is still narrowed...
    assert_select ".relation-filter input[name=q][value=?]", "Character one"
    assert_select ".relation-filter", text: /Showing 1 relation of 1 relation/
    # ...and the editor it reopens posts back to the narrowed list.
    assert_select "button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relations_path(universe_slug: @universe.slug, q: "Character one"), "Kept for another try"
  end

  test "a filter survives a rejected update and comes back on the edited row" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_three),
      character2: @character_one, description: "Raised together")

    patch universe_relation_url(universe_slug: @universe.slug, id: relation, q: "Raised"), params: {
      relation: { character2_id: "", description: "Rejected text" }
    }

    assert_response :unprocessable_content
    assert_select ".relation-filter input[name=q][value=?]", "Raised"
    assert_select ".entity-list .entity-row", count: 1
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_relation_path(universe_slug: @universe.slug, id: relation, q: "Raised"), "Rejected text"
  end

  test "deleting from a filtered list returns to the same narrowed list" do
    delete universe_relation_url(universe_slug: @universe.slug, id: relations(:relation_one), q: "Character one")

    assert_response :see_other
    assert_redirected_to universe_relations_path(universe_slug: @universe.slug, q: "Character one")
  end
end
