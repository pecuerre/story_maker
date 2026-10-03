class OwnershipsController < ApplicationController
  include PhotoParams
  include DraftMutation

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
    attributes = ownership_params
    @ownership = Current.universe.ownerships.new(attributes)
    return if remember_draft_create(@ownership, attributes)

    if @ownership.save
      redirect_to universe_ownerships_path(), notice: t("ownerships.flash.created")
    else
      load_form_options
      @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  # PATCH and DELETE answer with `see_other`, as the documented HTML flow
  # requires (`docs/architecture.md`): a 302 after a non-GET verb asks the
  # browser to repeat the mutation as a GET against the redirect target, which
  # Turbo then has to reinterpret. `create` is a POST, so its 302 is correct.
  def update
    attributes = ownership_params
    return if remember_draft_update(@ownership, attributes)

    if @ownership.update(attributes)
      redirect_to universe_ownerships_path(), notice: t("ownerships.flash.updated"), status: :see_other
    else
      load_form_options
      @ownerships = Current.universe.ownerships.includes(:item, :character, :ownership_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@ownership)

    @ownership.soft_delete
    redirect_to universe_ownerships_path(), notice: t("ownerships.flash.deleted"), status: :see_other
  end

  private

  def set_ownership
    @ownership = Current.universe.ownerships.find(params.expect(:id))
  end

  def ownership_params
    params.expect(ownership: [ :name, *photo_params, :item_id, :character_id, { ownership_tag_ids: [] }, :description, :from_date, :to_date ])
  end

  def load_form_options
    @items = Current.universe.items.order(:name, :id)
    @characters = Current.universe.characters.order(:name, :id)
    @ownership_tags = Current.universe.ownership_tags.where(taggable: true).order(:name, :id)
  end
end
