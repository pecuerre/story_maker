class OwnershipsController < ApplicationController
  before_action :set_ownership, only: %i[ update destroy ]

  def index
    load_form_options
    @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
  end

  def create
    @ownership = Current.universe.ownerships.new(ownership_params)

    if @ownership.save
      redirect_to universe_ownerships_path(), notice: "Ownership created."
    else
      load_form_options
      @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @ownership.update(ownership_params)
      redirect_to universe_ownerships_path(), notice: "Ownership updated."
    else
      load_form_options
      @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @ownership.destroy!
    redirect_to universe_ownerships_path(), notice: "Ownership deleted."
  end

  private

  def set_ownership
    @ownership = Current.universe.ownerships.find(params.expect(:id))
  end

  def ownership_params
    params.expect(ownership: [ :item_id, :character_id, { ownership_tag_ids: [] }, :description, :from_date, :to_date ])
  end

  def load_form_options
    @items = Current.universe.items.order(:name, :id)
    @characters = Current.universe.characters.order(:name, :id)
    @ownership_tags = Current.universe.ownership_tags.order(:name, :id)
  end
end
