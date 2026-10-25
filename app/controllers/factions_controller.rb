class FactionsController < ApplicationController
  include PhotoParams
  include RequiresJsonMutationFormat
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_faction, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    @factions = Current.universe.factions.includes(:photo, :faction_tags).order(:name, :id)
    @faction_tags = Current.universe.faction_tags.reorder(:position, :id).to_a
    @assignable_faction_tags = @faction_tags.select(&:taggable)
  end

  def show
  end

  def create
    attributes = faction_params
    @faction = Current.universe.factions.new(attributes)
    return if remember_draft_create(@faction, attributes)

    respond_to do |format|
      if @faction.save
        format.json { render json: faction_json, status: :created }
      else
        format.json { render json: @faction.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = faction_params
    return if remember_draft_update(@faction, attributes)

    respond_to do |format|
      if @faction.update(attributes)
        format.json { render json: faction_json, status: :ok }
      else
        format.json { render json: @faction.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@faction)

    @faction.soft_delete
    head :no_content
  end

  private

  def set_faction
    @faction = Current.universe.factions.find(params.expect(:id))
  end

  def faction_params
    params.expect(faction: [ *photo_params, :name, :mission, :actual_aims, :structure,
      :internal_divisions, :resources, :would_never, :would_absolutely, { faction_tag_ids: [] } ])
  end

  def faction_json
    {
      id: @faction.id,
      name: @faction.name,
      slug: @faction.slug,
      mission: @faction.mission,
      actual_aims: @faction.actual_aims,
      structure: @faction.structure,
      internal_divisions: @faction.internal_divisions,
      resources: @faction.resources,
      would_never: @faction.would_never,
      would_absolutely: @faction.would_absolutely,
      faction_tag_ids: @faction.faction_tag_ids,
      url: universe_faction_path(id: @faction)
    }
  end
end
