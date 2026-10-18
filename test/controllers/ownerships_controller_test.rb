require "test_helper"

class OwnershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @item = items(:item_one)
    @character = characters(:character_one)
    @ownership_tag = OwnershipTag.create!(universe: @universe, name: "Owns")
    sign_in_as(users(:user_one))
  end

  test "should get index with ownership options" do
    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Ownerships"
    assert_includes response.body, @item.name
    assert_includes response.body, @ownership_tag.name
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_ownerships_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]",
      universe_items_path(universe_slug: @universe.slug), text: "Items"
  end

  test "should create ownership and redirect" do
    assert_difference("Ownership.count") do
      post universe_ownerships_url(universe_slug: @universe.slug), params: {
        ownership: {
          item_id: @item.id,
          character_id: @character.id,
          ownership_tag_ids: [ @ownership_tag.id ],
          description: "Held by the character"
        }
      }
    end

    assert_redirected_to universe_ownerships_url(universe_slug: @universe.slug)
    assert_equal "Held by the character", Ownership.order(:id).last.description
  end

  test "should create an ownership without tags" do
    assert_difference("Ownership.count") do
      post universe_ownerships_url(universe_slug: @universe.slug), params: {
        ownership: {
          item_id: @item.id,
          character_id: @character.id,
          description: "No taxonomy needed"
        }
      }
    end

    assert_redirected_to universe_ownerships_url(universe_slug: @universe.slug)
    assert_empty Ownership.order(:id).last.ownership_tags
  end

  test "should update ownership and redirect" do
    ownership = Ownership.create!(universe: @universe, item: @item, character: @character)

    patch universe_ownership_url(universe_slug: @universe.slug, id: ownership), params: {
      ownership: { description: "Updated description" }
    }

    assert_redirected_to universe_ownerships_url(universe_slug: @universe.slug)
    assert_equal "Updated description", ownership.reload.description
  end

  test "a PATCH and a DELETE answer with see_other, not a 302" do
    ownership = Ownership.create!(universe: @universe, item: @item, character: @character)

    patch universe_ownership_url(universe_slug: @universe.slug, id: ownership), params: {
      ownership: { description: "Updated" }
    }

    assert_response :see_other

    delete universe_ownership_url(universe_slug: @universe.slug, id: ownership)

    assert_response :see_other
    assert_predicate ownership.reload, :deleted?
  end

  test "the optional name is accepted, offered back, and used as the label" do
    assert_difference("Ownership.count") do
      post universe_ownerships_url(universe_slug: @universe.slug), params: {
        ownership: {
          name: "Heirloom",
          item_id: @item.id,
          character_id: @character.id
        }
      }
    end

    ownership = Ownership.order(:id).last
    assert_equal "Heirloom", ownership.name
    # `display_string` and the composite slug both prefer a name when one is set,
    # so a name the editor could not write was a name nothing could display.
    assert_equal "Heirloom", ownership.display_string
    assert_equal "heirloom", ownership.slug

    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[name='ownership[name]']"
    # The editor for this row is prefilled from the serialized record, so the
    # stored name has to travel on that row's trigger.
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"name":"Heirloom"'
  end

  test "a stored name is renamed and cleared through the editor" do
    ownership = Ownership.create!(universe: @universe, item: @item, character: @character, name: "Old name")

    patch universe_ownership_url(universe_slug: @universe.slug, id: ownership), params: {
      ownership: { name: "New name" }
    }

    assert_equal "New name", ownership.reload.name

    patch universe_ownership_url(universe_slug: @universe.slug, id: ownership), params: {
      ownership: { name: "" }
    }

    # A blank name clears it rather than being rejected: the field is optional,
    # and the item and character remain the label.
    assert_nil ownership.reload.name
    assert_equal "#{@character.name} owns #{@item.name}", ownership.display_string
  end

  test "the datetime editors keep stored seconds" do
    ownership = Ownership.create!(universe: @universe, item: @item, character: @character,
      from_date: Time.utc(2026, 1, 2, 3, 4, 5), to_date: Time.utc(2027, 1, 2, 3, 4, 6))

    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[type=datetime-local][name='ownership[from_date]'][step='1']"
    assert_select "input[type=datetime-local][name='ownership[to_date]'][step='1']"
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"from_date":"2026-01-02T03:04:05"'
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"to_date":"2027-01-02T03:04:06"'
  end

  test "a rejected create states the reason and keeps the entered values in the editor" do
    assert_no_difference("Ownership.count") do
      post universe_ownerships_url(universe_slug: @universe.slug), params: {
        ownership: { item_id: @item.id, character_id: "", description: "Kept for another try" }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert]", text: /prevented this ownership from being saved/
    assert_select ".alert-danger[role=alert] li", text: /Character/
    assert_select "[data-modal-form-target='modal'] .alert-danger li", text: /Character/
    assert_select "button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_ownerships_path(universe_slug: @universe.slug), "Kept for another try"
  end

  # The filter, the sort, and the three empty states. `OwnershipFilterTest` covers
  # the value object; what only a request can show is the page around it — the
  # canonical URL, what the filter does to rows, and that it survives a re-render.
  test "index renders a search area that narrows, orders, and stays in the URL" do
    Ownership.create!(universe: @universe, character: characters(:character_three), item: items(:item_two),
      description: "Kept in the vault")

    get universe_ownerships_url(universe_slug: @universe.slug, q: "vault", sort: "created")

    assert_response :success
    assert_select "form[action=?][method=?]", universe_ownerships_path(universe_slug: @universe.slug), "get" do
      assert_select "input[name=q][value=?]", "vault"
      assert_select "select[name=sort] option[selected][value=?]", "created"
    end
    assert_select ".ownership-filter", text: /Showing 1 ownership of 2 ownerships/
    assert_select ".entity-list .entity-row", count: 1
  end

  test "index finds an ownership by the name of its item or its character" do
    # The label is composed from the two names and is translated chrome, so the
    # names are what a reader types.
    Ownership.create!(universe: @universe, character: characters(:character_three), item: items(:item_two))

    get universe_ownerships_url(universe_slug: @universe.slug, q: "Item two")

    assert_response :success
    assert_select ".entity-list .entity-row", count: 1
    assert_select ".ownership-filter", text: /Search: “Item two”/
  end

  test "index filters by an ownership tag" do
    Ownership.create!(universe: @universe, character: characters(:character_three), item: items(:item_two),
      ownership_tags: [ @ownership_tag ])

    get universe_ownerships_url(universe_slug: @universe.slug, ownership_tag_id: @ownership_tag.id)

    assert_response :success
    assert_select ".entity-list .entity-row", count: 1
    assert_select "select[name=ownership_tag_id] option[selected][value=?]", @ownership_tag.id
  end

  test "index redirects a form submission to the canonical filter query" do
    get universe_ownerships_url(universe_slug: @universe.slug, q: "vault", ownership_tag_id: "", sort: "")

    assert_redirected_to universe_ownerships_url(universe_slug: @universe.slug, q: "vault")
  end

  test "index reports an ownership tag it could not use instead of showing an empty list" do
    get universe_ownerships_url(universe_slug: @universe.slug, ownership_tag_id: ownership_tags(:ownership_tag_three).id)

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not an ownership tag of this universe/
    assert_select ".entity-list .entity-row", count: 1
  end

  test "index reports an order this list does not offer and falls back to the default" do
    get universe_ownerships_url(universe_slug: @universe.slug, sort: "password")

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not one this list offers/
    assert_select "select[name=sort] option[selected][value=?]", OwnershipFilter::DEFAULT_SORT
  end

  test "index separates a filtered empty result from a universe without ownerships" do
    get universe_ownerships_url(universe_slug: @universe.slug, q: "no such ownership")

    assert_response :success
    assert_select ".empty-title", text: "No ownerships match these filters"
    assert_select ".empty-description",
      text: /Universe one has 1 ownership, but none of them match the filters above/
    assert_select ".empty-state .badge", text: /Search: “no such ownership”/
    assert_select ".empty-state a", text: "Clear filters"
    assert_select ".ownership-filter a", text: "Clear filters", count: 0
    assert_select ".empty-state a", text: /Add ownership/, count: 0
  end

  test "a guest can filter and sees no mutation control" do
    sign_out

    get universe_ownerships_url(universe_slug: @universe.slug, q: "Item one")

    assert_response :success
    assert_select ".entity-list .entity-row", count: 1
    assert_select "form[data-controller=modal-form]", count: 0
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select ".ownership-filter input[name=q]", minimum: 1
  end

  test "a filter survives a rejected create and comes back on the editor" do
    post universe_ownerships_url(universe_slug: @universe.slug, q: "Item one"), params: {
      ownership: { item_id: @item.id, character_id: "", description: "Kept for another try" }
    }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert]", text: /prevented this ownership from being saved/
    assert_select ".ownership-filter input[name=q][value=?]", "Item one"
    assert_select ".ownership-filter", text: /Showing 1 ownership of 1 ownership/
    assert_select "button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_ownerships_path(universe_slug: @universe.slug, q: "Item one"), "Kept for another try"
  end

  test "a filter survives a rejected update and comes back on the edited row" do
    ownership = Ownership.create!(universe: @universe, character: characters(:character_three),
      item: items(:item_two), description: "Kept in the vault")

    patch universe_ownership_url(universe_slug: @universe.slug, id: ownership, q: "vault"), params: {
      ownership: { character_id: "", description: "Rejected text" }
    }

    assert_response :unprocessable_content
    assert_select ".ownership-filter input[name=q][value=?]", "vault"
    assert_select ".entity-list .entity-row", count: 1
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-url=?][data-modal-form-values-value*=?]",
      universe_ownership_path(universe_slug: @universe.slug, id: ownership, q: "vault"), "Rejected text"
  end

  test "deleting from a filtered list returns to the same narrowed list" do
    delete universe_ownership_url(universe_slug: @universe.slug, id: ownerships(:ownership_one), q: "Item one")

    assert_response :see_other
    assert_redirected_to universe_ownerships_path(universe_slug: @universe.slug, q: "Item one")
  end
end
