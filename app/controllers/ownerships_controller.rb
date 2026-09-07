class OwnershipsController < ApplicationController
  before_action :set_ownership, only: %i[ update destroy ]

  def index
    load_form_options
    @ownerships = Current.story.ownerships.includes(:item, :character, :ownership_type).order(:id)
  end

  def create
    @ownership = Current.story.ownerships.new(ownership_params)

    if @ownership.save
      redirect_to story_ownerships_path(story_slug: Current.story.slug), notice: "Ownership created."
    else
      load_form_options
      @ownerships = Current.story.ownerships.includes(:item, :character, :ownership_type).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @ownership.update(ownership_params)
      redirect_to story_ownerships_path(story_slug: Current.story.slug), notice: "Ownership updated."
    else
      load_form_options
      @ownerships = Current.story.ownerships.includes(:item, :character, :ownership_type).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @ownership.destroy!
    redirect_to story_ownerships_path(story_slug: Current.story.slug), notice: "Ownership deleted."
  end

  private

  def set_ownership
    @ownership = Current.story.ownerships.find(params.expect(:id))
  end

  def ownership_params
    params.expect(ownership: [ :item_id, :character_id, :ownership_type_id, :description, :from_date, :to_date ])
  end

  def load_form_options
    @items = Current.story.items.order(:name, :id)
    @characters = Current.story.characters.order(:name, :id)
    @ownership_types = Current.story.ownership_types.order(:name, :id)
  end
end
