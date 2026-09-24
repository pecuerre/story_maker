class TimelineController < ApplicationController
  allow_unauthenticated_access only: :index
  def index
    @events = Current.universe.events
      .includes(:event_tags, :before_event, :after_event, :simultaneous_event)
      .order(:id).to_a
    layout = TimelineLayout.new(@events)
    @layers = layout.layers
    @edges = layout.edges
  end
end
