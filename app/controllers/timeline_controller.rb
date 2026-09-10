class TimelineController < ApplicationController
  def index
    @events = Current.story.events
      .includes(:event_type, :before_event, :after_event, :simultaneous_event)
      .order(:id).to_a
    layout = TimelineLayout.new(@events)
    @layers = layout.layers
    @edges = layout.edges
  end
end
