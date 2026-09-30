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
end
