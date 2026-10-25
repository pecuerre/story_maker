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

  test "index rows show current owner when an ownership has no end date" do
    item = @universe.items.create!(name: "A fresh item")
    @universe.ownerships.create!(
      item: item,
      character: characters(:character_two),
      from_date: Time.utc(2026, 1, 1)
    )

    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-description", text: "Now with Character two"
  end

  test "index rows show historical owners when an ownership has an end date" do
    item = @universe.items.create!(name: "A fresh item")
    @universe.ownerships.create!(
      item: item,
      character: characters(:character_two),
      from_date: Time.utc(2026, 1, 1),
      to_date: Time.utc(2026, 6, 1)
    )

    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-description", text: "Previously with Character two"
  end

  test "index rows show both current and historical owners" do
    item = @universe.items.create!(name: "A fresh item")
    @universe.ownerships.create!(
      item: item,
      character: characters(:character_two),
      from_date: Time.utc(2026, 1, 1),
      to_date: Time.utc(2026, 6, 1)
    )
    @universe.ownerships.create!(
      item: item,
      character: characters(:character_three),
      from_date: Time.utc(2026, 7, 1)
    )

    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-description", text: "Previously with Character two"
    assert_select ".entity-description", text: "Now with Character three"
  end

  test "index does not issue per-row queries for ownerships" do
    3.times { |index| @universe.items.create!(name: "Listed #{index}") }

    with_fewer = count_queries(/FROM "ownerships"/) do
      get universe_items_url(universe_slug: @universe.slug)
    end

    3.times { |index| @universe.items.create!(name: "More #{index}") }

    with_more = count_queries(/FROM "ownerships"/) do
      get universe_items_url(universe_slug: @universe.slug)
    end

    assert_response :success
    # Eager loading keeps the ownerships query count flat as rows grow.
    assert_equal with_fewer, with_more
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

  test "should create and return an item's profile answers" do
    assert_difference("Item.count") do
      post universe_items_url(universe_slug: @universe.slug),
        params: { item: { name: "Gate Key", what_it_does: "Opens the sealed gate",
          origin: "The northern forge", cannot: "Open a gate already open" } },
        as: :json
    end

    assert_response :created
    item = Item.order(:id).last
    assert_equal [ "Opens the sealed gate", "The northern forge", "Open a gate already open" ],
      [ item.what_it_does, item.origin, item.cannot ]
    assert_equal "Opens the sealed gate", response.parsed_body["what_it_does"]
    assert_equal "The northern forge", response.parsed_body["origin"]
  end

  test "every declared profile field is permitted and persisted by an update" do
    # `Item::PROFILE_FIELDS` drives the editor and the page, while strong
    # parameters list the keys by hand so `TranslationsTest` can see them. This is
    # the assertion that the two lists agree.
    answers = Item::PROFILE_FIELDS.to_h { |field| [ field, "answer for #{field}" ] }

    patch universe_item_url(universe_slug: @universe.slug, id: @item),
      params: { item: answers }, as: :json

    assert_response :success
    @item.reload
    Item::PROFILE_FIELDS.each do |field|
      assert_equal "answer for #{field}", @item.public_send(field), "#{field} was not persisted"
      assert_equal "answer for #{field}", response.parsed_body[field.to_s]
    end
  end

  test "the details page lists every profile answer with its group and a blank message" do
    item = @universe.items.create!(name: "Gate Key", what_it_does: "Opens the sealed gate", jargon: "Gate-key")

    get universe_item_url(universe_slug: @universe.slug, id: item)

    assert_response :success
    assert_select "dt", text: "What it does"
    assert_select "dt", text: "Origin"
    assert_select "dt", text: "Jargon"
    assert_includes fact_values, [ "What it does", "Opens the sealed gate" ]
    assert_includes fact_values, [ "Jargon", "Gate-key" ]
    assert_includes fact_values, [ "Origin", "Not recorded yet." ]
  end

  test "the details page names the item's current and previous owners" do
    item = @universe.items.create!(name: "A fresh item")
    @universe.ownerships.create!(
      item: item,
      character: characters(:character_two),
      from_date: Time.utc(2026, 1, 1),
      to_date: Time.utc(2026, 6, 1)
    )
    @universe.ownerships.create!(
      item: item,
      character: characters(:character_three),
      from_date: Time.utc(2026, 7, 1)
    )

    get universe_item_url(universe_slug: @universe.slug, id: item)

    assert_response :success
    assert_includes fact_values, [ "Currently owned by", "Character three" ]
    assert_includes fact_values, [ "Previously owned by", "Character two" ]
  end

  test "the details page states when an item has no recorded owner" do
    item = @universe.items.create!(name: "A fresh item")

    get universe_item_url(universe_slug: @universe.slug, id: item)

    assert_response :success
    assert_includes fact_values, [ "Currently owned by", "No current owner is recorded." ]
    assert_includes fact_values, [ "Previously owned by", "No previous owner is recorded." ]
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

  private
    # The identity block's [label, value] pairs, so an assertion can tie a value
    # to the label it belongs to.
    def fact_values
      Nokogiri::HTML(response.body).css(".detail-fact").map do |fact|
        [ fact.at_css("dt").text.strip, fact.at_css("dd").text.strip ]
      end
    end
end
