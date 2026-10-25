# The API-surface counterpart of `ItemsController`: index and show as JSON.
class Api::ItemsController < Api::BaseController
  before_action :set_item, only: %i[ show ]

  # GET /api/u/:universe_slug/items
  def index
    @items = Current.universe.items.order(:position, :id)
    render json: @items.map { |item| item_json(item) }
  end

  # GET /api/u/:universe_slug/items/:id
  def show
    render json: item_json(@item)
  end

  private

    def set_item
      @item = Current.universe.items.find(params.expect(:id))
    end

    def item_json(item)
      {
        id: item.id,
        name: item.name,
        description: item.description,
        **Item::PROFILE_FIELDS.to_h { |field| [ field, item.public_send(field) ] },
        item_tag_ids: item.item_tag_ids,
        parent_id: item.parent_id,
        position: item.position
      }
    end
end
