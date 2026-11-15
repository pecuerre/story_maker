# The read-only comparison of a Story's narrative order with the Universe
# Timeline. There is no `allow_unauthenticated_access` here on purpose: the page
# is for signed-in readers, and the shared authentication callback is the whole
# of that rule. Everything after sign-in is the ordinary universe read
# authorization.
#
# The page has two views of the same comparison, each with its own URL: the two
# side-by-side lists (`?view` absent) and the chart (`?view=chart`). They read the
# same `NarrativeComparison`; only the presentation differs.
class NarrativeOrdersController < ApplicationController
  before_action :set_story

  def show
    events = Current.universe.events
      .includes(:before_event, :after_event, :simultaneous_event)
      .order(:id)
      .to_a
    scenes = @story.scenes.includes(:section, scene_events: :event).order(:position, :id)
    @comparison = NarrativeComparison.new(scenes: scenes, layout: TimelineLayout.new(events))
    @view = params[:view] == "chart" ? "chart" : "list"
    @chart = NarrativeChartLayout.new(@comparison) if @view == "chart"
  end
end
