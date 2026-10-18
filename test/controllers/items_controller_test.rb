require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @item = items(:item_one)
    @item_tag = item_tags(:item_tag_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with item tag options" do
    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Items"
    assert_includes response.body, "Item tag"
    assert_includes response.body, @item.name
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_items_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]",
      universe_ownerships_path(universe_slug: @universe.slug), text: "Ownerships"
  end

  # The names in the order the list rendered them, so a filter or a sort
  # assertion says which items survived it without depending on row markup.
  def listed_item_names
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
  end

  # The filter, the sort, and the two empty states. The value object is covered
  # in `ItemFilterTest`; what a request can show and this cannot is the page
  # around it — the canonical URL, and what a filter does to the list.
  test "index renders a search area that narrows, orders, and stays in the URL" do
    @item.update!(description: "The keeper of the gate")

    get universe_items_url(universe_slug: @universe.slug, q: "keeper", sort: "created")

    assert_response :success
    assert_select "form[action=?][method=?]", universe_items_path(universe_slug: @universe.slug), "get" do
      assert_select "input[name=q][value=?]", "keeper"
      assert_select "select[name=sort] option[selected][value=?]", "created"
    end
    assert_select ".item-filter", text: /Showing 1 item of 2 items/
    assert_equal [ @item.name ], listed_item_names
  end

  test "index orders the whole list by the reader's choice" do
    items(:item_one).update!(created_at: Time.utc(2026, 1, 1))
    items(:item_two).update!(created_at: Time.utc(2026, 3, 1))

    get universe_items_url(universe_slug: @universe.slug, sort: "created")

    assert_response :success
    assert_equal [ "Item two", "Item one" ], listed_item_names
  end

  test "index filters by an item tag" do
    get universe_items_url(universe_slug: @universe.slug, item_tag_id: item_tags(:item_tag_one).id)

    assert_response :success
    assert_equal [ "Item one" ], listed_item_names
    assert_select "select[name=item_tag_id] option[selected][value=?]",
      item_tags(:item_tag_one).id
  end

  test "index filters by a grouping item tag" do
    get universe_items_url(universe_slug: @universe.slug, item_tag_id: item_tags(:item_tag_two).id)

    assert_response :success
    # `item_tag_two` is `taggable: false`, so the editor's picker cannot offer
    # it, but the filter accepts it: `item_two` carries it.
    assert_equal [ "Item two" ], listed_item_names
    assert_select "select[name=item_tag_id] option[selected][value=?]",
      item_tags(:item_tag_two).id
  end

  test "index redirects a form submission to the canonical filter query" do
    get universe_items_url(universe_slug: @universe.slug, q: "keeper", item_tag_id: "", sort: "")

    assert_redirected_to universe_items_url(universe_slug: @universe.slug, q: "keeper")
  end

  test "index reports a filter value it could not use instead of showing an empty list" do
    get universe_items_url(universe_slug: @universe.slug, item_tag_id: item_tags(:item_tag_three).id)

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not an item tag of this universe/
    assert_equal [ "Item one", "Item two" ], listed_item_names
  end

  test "index reports an order this list does not offer and falls back to the default" do
    get universe_items_url(universe_slug: @universe.slug, sort: "password")

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not one this list offers/
    assert_select "select[name=sort] option[selected][value=?]", ItemFilter::DEFAULT_SORT
    assert_equal [ "Item one", "Item two" ], listed_item_names
  end

  test "index separates a filtered empty result from a universe without items" do
    get universe_items_url(universe_slug: @universe.slug, q: "no such item")

    assert_response :success
    assert_select ".empty-title", text: "No items match these filters"
    assert_select ".empty-description",
      text: /Universe one has 2 items, but none of them match the filters above/
    assert_select ".empty-state .badge", text: /Search: “no such item”/
    assert_select ".empty-state a", text: "Clear filters"
    assert_select ".item-filter a", text: "Clear filters", count: 0
    assert_select ".empty-state a", text: /Add item/, count: 0
  end

  test "a guest can filter and sees no mutation control" do
    sign_out

    get universe_items_url(universe_slug: @universe.slug, q: "Item one")

    assert_response :success
    assert_equal [ "Item one" ], listed_item_names
    assert_select "form[data-controller=modal-form]", count: 0
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select ".item-filter input[name=q]", minimum: 1
  end

  test "should create item as json" do
    assert_difference("Item.count") do
      post universe_items_url(universe_slug: @universe.slug),
        params: { item: { name: "New item", description: "A description", item_tag_ids: [ @item_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @item_tag.id ], response.parsed_body["item_tag_ids"]
    assert_equal "A description", Item.order(:id).last.description
  end

  test "should create an item without tags" do
    assert_difference("Item.count") do
      post universe_items_url(universe_slug: @universe.slug),
        params: { item: { name: "Untagged item" } },
        as: :json
    end

    assert_response :created
    assert_empty response.parsed_body["item_tag_ids"]
    assert_empty Item.order(:id).last.item_tags
  end

  test "should reject item tags from another universe" do
    foreign_tag = item_tags(:item_tag_three)
    join_count = -> { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM items_item_tags") }

    assert_no_difference([ "Item.count", join_count ]) do
      post universe_items_url(universe_slug: @universe.slug),
        params: { item: { name: "Mis-scoped item", item_tag_ids: [ foreign_tag.id ] } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["item_tags"]
  end

  test "the item delete confirmation states that scenes and other records remain" do
    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    # The item row is a JSON-only workspace, so its delete control is the modal
    # controller's button rather than a Turbo `button_to`. The mandatory consequence
    # copy is carried by that control and must not be weakened.
    assert_select "button[data-action='modal-form#destroy'][data-modal-form-url=?][data-modal-form-confirm=?]",
      universe_item_path(universe_slug: @universe.slug, id: @item),
      "Delete “#{@item.name}”? Its descendant items, ownerships, tag assignments, and links to " \
      "scenes will be permanently removed. Scenes and other universe records will remain."
  end

  test "should update item details as json" do
    patch universe_item_url(universe_slug: @universe.slug, id: @item),
      params: { item: { name: "Renamed", description: "Updated", item_tag_ids: [ @item_tag.id ] } },
      as: :json

    assert_response :success
    @item.reload
    assert_equal [ "Renamed", "Updated", [ @item_tag.id ] ], [ @item.name, @item.description, @item.item_tag_ids ]
  end
end
