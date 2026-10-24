# The external-tool surface for Routes follows the same JSON and draft-aware
# mutation contract as the other universe-scoped link records.
class Api::RoutesController < Api::BaseController
  include RequiresJsonMutationFormat
  include DraftMutation

  before_action :set_route, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    @routes = Current.universe.routes.order(:id)
    render json: @routes.map { |route| route_json(route) }
  end

  def show
    render json: route_json(@route)
  end

  def create
    attributes = route_params
    @route = Current.universe.routes.new(attributes)
    return if remember_draft_create(@route, attributes)

    if @route.save
      render json: route_json(@route), status: :created
    else
      render json: @route.errors, status: :unprocessable_content
    end
  end

  def update
    attributes = route_params
    return if remember_draft_update(@route, attributes)

    if @route.update(attributes)
      render json: route_json(@route)
    else
      render json: @route.errors, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@route)

    @route.soft_delete
    head :no_content
  end

  private

  def set_route
    @route = Current.universe.routes.find(params.expect(:id))
  end

  def route_json(route)
    {
      id: route.id,
      name: route.name,
      description: route.description,
      from_location_id: route.from_location_id,
      to_location_id: route.to_location_id,
      distance: route.distance,
      duration: route.duration,
      slug: route.slug
    }
  end

  def route_params
    params.expect(route: [ :name, :from_location_id, :to_location_id, :distance, :duration, :description ])
  end
end
