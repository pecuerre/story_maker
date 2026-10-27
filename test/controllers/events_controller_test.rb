require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @event = events(:event_one)
    @event_one = events(:event_one)
    @event_two = events(:event_two)
    # `Event#set_name` fills the stored `name` from the title only when a record
    # is saved, and the fixture loader inserts without callbacks, so both names
    # are assigned here like a title a reader sees.
    @event_one.update!(name: @event_one.title)
    @event_two.update!(name: @event_two.title)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Events"
    assert_includes response.body, @event.title
  end

  # An event with no title and no dates is named through the event it references,
  # so its label reads a temporal association. The label is printed several times
  # over per row — the name, the delete confirmation, and the modal's three
  # reference pickers — and the references have to come with the list rather than
  # with each row.
  # The names in the order the list rendered them, so a filter or a sort
  # assertion says which events survived it without depending on row markup.
  def listed_event_labels
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
  end

  # The filter, the sort, and the two empty states. The value object is covered
  # in `EventFilterTest`; what a request can show and this cannot is the page
  # around it — the canonical URL, and what a filter does to the list.
  test "index renders a search area that narrows, orders, and stays in the URL" do
    get universe_events_url(universe_slug: @universe.slug, q: "beginning", sort: "created")

    assert_response :success
    assert_select "form[action=?][method=?]",
      universe_events_path(universe_slug: @universe.slug), "get" do
      assert_select "input[name=q][value=?]", "beginning"
      assert_select "select[name=sort] option[selected][value=?]", "created"
    end
    assert_select ".event-filter", text: /Showing 1 event of 2 events/
  end

  test "index orders the whole list by the reader's choice" do
    events(:event_one).update!(created_at: Time.utc(2026, 1, 1))
    events(:event_two).update!(created_at: Time.utc(2026, 3, 1))

    get universe_events_url(universe_slug: @universe.slug, sort: "created")

    assert_response :success
    assert_equal [ @event_two.display_label, @event_one.display_label ], listed_event_labels
  end

  test "index narrows by the days an event starts" do
    get universe_events_url(universe_slug: @universe.slug, from: "2026-09-11", to: "2026-09-11")

    assert_response :success
    assert_equal [ @event_one.display_label, @event_two.display_label ], listed_event_labels
  end

  test "index filters by an event tag" do
    @event_one.update!(event_tag_ids: [ event_tags(:event_tag_one).id ])

    get universe_events_url(universe_slug: @universe.slug,
      event_tag_id: event_tags(:event_tag_one).id)

    assert_response :success
    assert_equal [ @event_one.display_label ], listed_event_labels
    assert_select "select[name=event_tag_id] option[selected][value=?]",
      event_tags(:event_tag_one).id
  end

  test "index redirects a form submission to the canonical filter query" do
    get universe_events_url(universe_slug: @universe.slug, from: "2026-09-11", to: "", sort: "")

    assert_redirected_to universe_events_url(universe_slug: @universe.slug, from: "2026-09-11")
  end

  test "index reports a filter value it could not use instead of showing an empty list" do
    get universe_events_url(universe_slug: @universe.slug,
      event_tag_id: event_tags(:event_tag_three).id)

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not an event tag of this universe/
    assert_equal [ @event_one.display_label, @event_two.display_label ], listed_event_labels
  end

  test "index reports a day it could not read" do
    get universe_events_url(universe_slug: @universe.slug, from: "not-a-day")

    assert_response :success
    assert_select ".flash-alert, .alert", text: /could not be read/
    assert_equal [ @event_one.display_label, @event_two.display_label ], listed_event_labels
  end

  test "index reports an order this list does not offer and falls back to the default" do
    get universe_events_url(universe_slug: @universe.slug, sort: "password")

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not one this list offers/
    assert_select "select[name=sort] option[selected][value=?]", EventFilter::DEFAULT_SORT
    assert_equal [ @event_one.display_label, @event_two.display_label ], listed_event_labels
  end

  test "index separates a filtered empty result from a universe without events" do
    get universe_events_url(universe_slug: @universe.slug, q: "no such event")

    assert_response :success
    assert_select ".empty-title", text: "No events match these filters"
    assert_select ".empty-description",
      text: /Universe one has 2 events, but none of them match the filters above/
    assert_select ".empty-state .badge", text: /Search: “no such event”/
    assert_select ".empty-state a", text: "Clear filters"
    assert_select ".event-filter a", text: "Clear filters", count: 0
    assert_select ".empty-state a", text: /Add event/, count: 0
  end

  test "a guest can filter and sees no mutation control" do
    sign_out

    get universe_events_url(universe_slug: @universe.slug, q: "The end")

    assert_response :success
    assert_equal [ @event_two.display_label ], listed_event_labels
    assert_select "form[data-controller=modal-form]", count: 0
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select ".event-filter input[name=q]", minimum: 1
  end

  test "adding a reference-only event does not add a query for that event" do
    anchor = events(:event_one)
    @universe.events.create!(before_event: anchor)

    with_one = count_queries(/FROM "events"/) do
      get universe_events_url(universe_slug: @universe.slug)
    end

    3.times { @universe.events.create!(before_event: anchor) }

    with_four = count_queries(/FROM "events"/) do
      get universe_events_url(universe_slug: @universe.slug)
    end

    assert_response :success
    assert_equal with_one, with_four
  end

  test "should create event with only a title as json" do
    assert_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { title: "New event" } },
        as: :json
    end

    assert_response :created
    assert_equal "New event", response.parsed_body["title"]
  end

  test "should create a tagged event as json" do
    event_tag = event_tags(:event_tag_two)

    assert_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { title: "Tagged event", event_tag_ids: [ event_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ event_tag.id ], response.parsed_body["event_tag_ids"]
  end

  test "should not create an event with no identifying attribute" do
    assert_no_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { description: "Just a description" } },
        as: :json
    end

    assert_response :unprocessable_content
  end

  test "should reject event tags from another universe" do
    foreign_tag = event_tags(:event_tag_three)
    join_count = -> { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM events_event_tags") }

    assert_no_difference([ "Event.count", join_count ]) do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { title: "Mis-scoped event", event_tag_ids: [ foreign_tag.id ] } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["event_tags"]
  end

  test "should update event details as json" do
    patch universe_event_url(universe_slug: @universe.slug, id: @event),
      params: { event: { title: "Renamed" } },
      as: :json

    assert_response :success
    assert_equal "Renamed", @event.reload.title
    assert_equal "Renamed", @event.name
    assert_equal "renamed", @event.slug
  end

  test "should destroy event" do
    assert_difference("Event.count", -1) do
      delete universe_event_url(universe_slug: @universe.slug, id: @event), as: :json
    end

    assert_response :no_content
  end

  test "should destroy an event referenced by another event" do
    reference = Event.create!(universe: @universe, title: "Reference", before_event: @event)

    assert_difference("Event.count", -1) do
      delete universe_event_url(universe_slug: @universe.slug, id: @event), as: :json
    end

    assert_response :no_content
    assert_nil reference.reload.before_event
  end

  test "should destroy an event referenced by a scene without deleting the scene" do
    scene = scenes(:scene_one)
    assert_includes scene.events, @event

    assert_difference("Event.count", -1) do
      assert_no_difference("Scene.count") do
        delete universe_event_url(universe_slug: @universe.slug, id: @event), as: :json
      end
    end

    assert_empty scene.reload.events
    assert_equal stories(:story_one), scene.story
  end

  test "the three temporal selects do not offer the row being edited" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    # One modal form serves every row, so the server cannot know which row the
    # browser is about to edit: it sends every universe event. Each select says
    # it must not offer the row being edited, and each row's trigger carries the
    # id that identifies which option that is.
    assert_select "select[data-modal-form-exclude-self]", 3
    assert_select "select[name='event[before_event_id]'][data-modal-form-exclude-self]", 1
    assert_select "select[name='event[after_event_id]'][data-modal-form-exclude-self]", 1
    assert_select "select[name='event[simultaneous_event_id]'][data-modal-form-exclude-self]", 1
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-record-id=?]",
      @event.id.to_s
    assert_select "select[name='event[before_event_id]'] option[value=?]", @event.id.to_s, 1
  end

  test "a self reference built by hand is still refused and keyed on the association" do
    patch universe_event_url(universe_slug: @universe.slug, id: @event),
      params: { event: { before_event_id: @event.id } },
      as: :json

    assert_response :unprocessable_content
    # The browser no longer offers the choice, so this is the only way to reach
    # the rule: the model is the authority, and it keys the error on the
    # association so the modal can show it beside the foreign-key control.
    assert_equal [ "cannot be itself" ], response.parsed_body["before_event"]
    assert_nil @event.reload.before_event_id
  end

  test "the datetime editors keep stored seconds" do
    # Both halves of one contract: the control accepts a second (`step: 1`) and the
    # serialized value carries it, so opening an editor and saving it again does
    # not rewrite the stored second as zero.
    @event.update!(start_datetime: Time.utc(2026, 3, 1, 9, 0, 30))

    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[type=datetime-local][name='event[start_datetime]'][step='1']"
    assert_select "input[type=datetime-local][name='event[end_datetime]'][step='1']"
    assert_select ".row-actions button[data-action='modal-form#open'][data-modal-form-values-value*=?]",
      '"start_datetime":"2026-03-01T09:00:30"'
  end

  test "index row renders the in-world date range as metadata" do
    event = @universe.events.create!(
      title: "The middle",
      start_datetime: Time.utc(2026, 9, 11, 9, 0),
      end_datetime: Time.utc(2026, 9, 11, 10, 0)
    )

    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-list .entity-description",
      text: "2026-09-11 09:00 – 2026-09-11 10:00"
  end

  test "index row renders related events as metadata" do
    anchor = events(:event_one)
    @universe.events.create!(title: "The middle", before_event: anchor)

    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    # `event_one`'s label is its title plus its start datetime.
    assert_select ".entity-list .entity-description",
      text: "before The beginning - 2026-09-11 09:00"
  end

  test "index does not issue per-row queries for temporal references" do
    anchor = events(:event_one)
    3.times { @universe.events.create!(title: "Referrer #{_1}", before_event: anchor) }

    with_fewer = count_queries(/FROM "events"/) do
      get universe_events_url(universe_slug: @universe.slug)
    end

    3.times { @universe.events.create!(title: "More #{_1}", before_event: anchor) }

    with_more = count_queries(/FROM "events"/) do
      get universe_events_url(universe_slug: @universe.slug)
    end

    assert_response :success
    # Eager loading keeps the events query count flat as rows grow.
    assert_equal with_fewer, with_more
  end

  test "the event delete confirmation states that scenes remain" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    # The event row is a JSON-only workspace, so its delete control is the modal
    # controller's button rather than a Turbo `button_to`. The mandatory
    # consequence copy is carried by that control and must not be weakened.
    assert_select "button[data-action='modal-form#destroy'][data-modal-form-url=?][data-modal-form-confirm=?]",
      universe_event_path(universe_slug: @universe.slug, id: @event),
      "Delete “#{@event.display_string}”? Its child events, tag assignments, and any temporal " \
      "referrers that would become unidentifiable will be permanently removed; other temporal " \
      "references and Scene links will be cleared. Scenes will remain."
  end
end
