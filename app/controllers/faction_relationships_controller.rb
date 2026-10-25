class FactionRelationshipsController < ApplicationController
  include PhotoParams
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_faction_relationship, only: %i[ show update destroy ]

  def index
    load_index_data
  end

  def show
  end

  def create
    attributes = faction_relationship_params
    @faction_relationship = Current.universe.faction_relationships.new(attributes)
    return if remember_draft_create(@faction_relationship, attributes)

    if @faction_relationship.save
      redirect_to universe_faction_relationships_path(), notice: t("faction_relationships.flash.created")
    else
      load_index_data
      render :index, status: :unprocessable_content
    end
  end

  # PATCH and DELETE use the same see_other response as the other HTML editors.
  def update
    attributes = faction_relationship_params
    return if remember_draft_update(@faction_relationship, attributes)

    if @faction_relationship.update(attributes)
      redirect_to universe_faction_relationships_path(), notice: t("faction_relationships.flash.updated"), status: :see_other
    else
      load_index_data
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@faction_relationship)

    @faction_relationship.soft_delete
    redirect_to universe_faction_relationships_path(), notice: t("faction_relationships.flash.deleted"), status: :see_other
  end

  private

  def load_index_data
    @faction_relationships = Current.universe.faction_relationships
      .includes(:from_faction, :to_faction, :photo)
      .order(:id)
    @factions = Current.universe.factions.order(:name, :id)
    @rejected = @faction_relationship&.errors&.any? ? @faction_relationship : nil
  end

  def set_faction_relationship
    @faction_relationship = Current.universe.faction_relationships.find(params.expect(:id))
  end

  def faction_relationship_params
    params.expect(faction_relationship: [ :name, *photo_params, :from_faction_id, :to_faction_id,
      :description, :from_date, :to_date ])
  end
end
