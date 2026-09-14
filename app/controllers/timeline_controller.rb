class TimelineController < ApplicationController
  def index
    @events = Current.universe.events
      .includes(:event_types, :before_event, :after_event, :simultaneous_event)
      .order(:id).to_a
    layout = TimelineLayout.new(@events)
    @layers = layout.layers
    @edges = layout.edges
  end
end
