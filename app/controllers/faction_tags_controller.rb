class FactionTagsController < ApplicationController
  include PhotoParams
  include TagDetails
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :faction_tag
  filters_list_with FactionTagFilter, only: %i[ index ]

  before_action :set_faction_tag, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    @list_filter = FactionTagFilter.new(@filter_query)
    return redirect_to_canonical_filtered_list if blank_filter_values?

    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      Current.universe.faction_tags.includes(:photo)))
    @faction_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(Current.universe.faction_tags)
    @faction_tag_total = Current.universe.faction_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  def show
    load_tag_details(@faction_tag)
  end

  def create
    attributes = faction_tag_params
    @faction_tag = Current.universe.faction_tags.new(attributes)
    return if remember_draft_create(@faction_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@faction_tag, requested_position: attributes[:position])
        format.json { render json: faction_tag_json, status: :created }
      else
        format.json { render json: @faction_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = faction_tag_params
    return if remember_draft_update(@faction_tag, attributes)

    respond_to do |format|
      if update_with_sibling_position(@faction_tag, attributes)
        format.json { render json: faction_tag_json, status: :ok }
      else
        format.json { render json: @faction_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@faction_tag)

    destroy_with_sibling_position(@faction_tag)
    head :no_content
  end

  private

  def set_faction_tag
    @faction_tag = Current.universe.faction_tags.find(params.expect(:id))
  end

  def faction_tag_params
    params.expect(faction_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor,
      :parent_id, :position, :taggable, :show_in_menu ])
  end

  def filtered_list_path_with(query)
    path = universe_faction_tags_path
    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def faction_tag_json
    {
      id: @faction_tag.id,
      name: @faction_tag.name,
      description: @faction_tag.description,
      bgcolor: @faction_tag.bgcolor,
      fgcolor: @faction_tag.fgcolor,
      parent_id: @faction_tag.parent_id,
      position: @faction_tag.position,
      taggable: @faction_tag.taggable,
      show_in_menu: @faction_tag.show_in_menu,
      url: universe_faction_tag_path(id: @faction_tag)
    }
  end
end
