class OwnershipsController < ApplicationController
  include PhotoParams

  allow_unauthenticated_access only: %i[ index show ]
  before_action :set_ownership, only: %i[ show update destroy ]

  def index
    load_form_options
    @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
  end

  # GET /ownerships/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def create
    @ownership = Current.universe.ownerships.new(ownership_params)

    if @ownership.save
      redirect_to universe_ownerships_path(), notice: t("ownerships.flash.created")
    else
      load_form_options
      @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @ownership.update(ownership_params)
      redirect_to universe_ownerships_path(), notice: t("ownerships.flash.updated")
    else
      load_form_options
      @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @ownership.soft_delete
    redirect_to universe_ownerships_path(), notice: t("ownerships.flash.deleted")
  end

  private

  def set_ownership
    @ownership = Current.universe.ownerships.find(params.expect(:id))
  end

  def ownership_params
    params.expect(ownership: [ *photo_params, :item_id, :character_id, { ownership_tag_ids: [] }, :description, :from_date, :to_date ])
  end

  def load_form_options
    @items = Current.universe.items.order(:name, :id)
    @characters = Current.universe.characters.order(:name, :id)
    @ownership_tags = Current.universe.ownership_tags.where(taggable: true).order(:name, :id)
  end
end
