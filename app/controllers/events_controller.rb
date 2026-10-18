class EventsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :event

  before_action :set_event, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # The filter keys ride along with the index. The list's mutations are JSON and
  # answer with no redirect, so nothing on this controller has to carry a filter
  # back: `modal_form_controller.js` refreshes the same URL the reader is on.
  filters_list_with EventFilter, only: %i[ index ]

  def index
    set_event_tag_data

    @list_filter = EventFilter.new(@filter_query, event_tags: @event_tags)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # An event with no title and no dates is labelled through the event it
    # references, so the three temporal associations are loaded here for the
    # same reason the tags are: the list prints that label several times over —
    # the name, the row's delete confirmation, and the modal's three reference
    # pickers — and each print would otherwise read its own association.
    # `TimelineController#index` loads the same four.
    @events = @list_filter.apply(Current.universe.events.includes(
      :event_tags, :before_event, :after_event, :simultaneous_event))
    # The same narrowed relation feeds the edit form's three temporal-reference
    # pickers, so a reader cannot be offered an event their filter excluded.
    @events_for_select = @events
    # The universe total is read only to say what the reader is looking at out
    # of, so an ordinary unfiltered visit costs no extra query for it. One
    # aggregate is enough: a narrowed list must not mistake its own size for
    # how many events the universe holds.
    @event_total = Current.universe.events.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /events/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def create
    attributes = event_params
    @event = Current.universe.events.new(attributes)
    return if remember_draft_create(@event, attributes)

    respond_to do |format|
      if create_with_sibling_position(@event, requested_position: attributes[:position])
        format.json { render json: event_json, status: :created }
      else
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = event_params
    return if remember_draft_update(@event, attributes)

    respond_to do |format|
      if update_event(attributes)
        format.json { render json: event_json, status: :ok }
      else
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@event)

    destroy_with_sibling_position(@event)
    head :no_content
  end

  private

  # Event Tag definitions and their paths are universe-scoped. One ordered tag
  # query serves the list filter and its tag selector, and the same list builds
  # the root-first paths a hierarchical taxonomy is named by.
  #
  # The **editor** offers assignable tags only — a grouping tag stays in the tree
  # and on records that already carry one — so the two lists are deliberately
  # different. The filter validates against every tag, because a reader
  # filtering by a grouping tag is asking about records that really do carry it.
  def set_event_tag_data
    @event_tags = Current.universe.event_tags.reorder(:position, :id).to_a
    @assignable_event_tags = @event_tags.select(&:taggable)
    @event_tag_paths = EventTagPaths.build(@event_tags)
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_events_path

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def set_event
    @event = Current.universe.events.find(params.expect(:id))
  end

  def event_params
    params.expect(event: [ *photo_params, :title, :start_datetime, :end_datetime, :before_event_id, :after_event_id,
      :simultaneous_event_id, :description, { event_tag_ids: [] }, :parent_id, :position ])
  end

  def update_event(attributes)
    update_with_sibling_position(@event, attributes)
  end

  def event_json
    {
      id: @event.id,
      title: @event.title,
      start_datetime: @event.start_datetime,
      end_datetime: @event.end_datetime,
      before_event_id: @event.before_event_id,
      after_event_id: @event.after_event_id,
      simultaneous_event_id: @event.simultaneous_event_id,
      description: @event.description,
      event_tag_ids: @event.event_tag_ids,
      parent_id: @event.parent_id,
      position: @event.position,
      display_string: @event.display_label,
      url: universe_event_path(id: @event)
    }
  end
end
