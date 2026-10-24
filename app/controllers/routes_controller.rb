class RoutesController < ApplicationController
  include PhotoParams
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_route, only: %i[ show update destroy ]

  def index
    @locations = Current.universe.locations.order(:name, :id)
    @routes = Current.universe.routes.includes(:from_location, :to_location).order(:id)
  end

  def show
  end

  def create
    attributes = route_params
    @route = Current.universe.routes.new(attributes)
    return if remember_draft_create(@route, attributes)

    if @route.save
      redirect_to universe_routes_path, notice: t("routes.flash.created")
    else
      load_routes
      render :index, status: :unprocessable_content
    end
  end

  def update
    attributes = route_params
    return if remember_draft_update(@route, attributes)

    if @route.update(attributes)
      redirect_to universe_routes_path, notice: t("routes.flash.updated"), status: :see_other
    else
      load_routes
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@route)

    @route.soft_delete
    redirect_to universe_routes_path, notice: t("routes.flash.deleted"), status: :see_other
  end

  private

  def load_routes
    @locations = Current.universe.locations.order(:name, :id)
    @routes = Current.universe.routes.includes(:from_location, :to_location).order(:id)
  end

  def set_route
    @route = Current.universe.routes.find(params.expect(:id))
  end

  def route_params
    params.expect(route: [ :name, *photo_params, :from_location_id, :to_location_id, :distance, :duration, :description ])
  end
end
