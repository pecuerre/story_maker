class TimelineController < ApplicationController
  def index
    @events = Current.story.events.order(:id).to_a
    layout = TimelineLayout.new(@events)
    @layers = layout.layers
    @edges = layout.edges
  end
end
