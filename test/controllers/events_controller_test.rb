require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @event = events(:event_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Events"
    assert_includes response.body, @event.title
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
    assert_equal @event, scene.event

    assert_difference("Event.count", -1) do
      assert_no_difference("Scene.count") do
        delete universe_event_url(universe_slug: @universe.slug, id: @event), as: :json
      end
    end

    assert_nil scene.reload.event
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
