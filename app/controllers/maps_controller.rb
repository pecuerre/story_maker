class MapsController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    locations = Current.universe.locations.order(:position, :id).to_a
    @hierarchy = HierarchyIndex.build(locations)
    @routes = Current.universe.routes.includes(:from_location, :to_location).order(:id)
    @map_layout = LocationMapLayout.new(locations: @hierarchy.records, routes: @routes)
  end
end
