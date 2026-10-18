class SectionTagsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :section_tag

  # The filter rides along with the index. A tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with SectionTagFilter, only: %i[ index ]

  before_action :set_story
  before_action :set_section_tag,
    only: %i[ show update destroy ]

  # GET /section_tags or /section_tags.json
  def index
    @list_filter = SectionTagFilter.new(@filter_query)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      @story.section_tags.includes(:photo)))
    @section_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(@story.section_tags)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @section_tag_total = @story.section_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # POST /section_tags or /section_tags.json
  # GET /section_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    @include_descendants = params[:include_descendants] != "0"
    @tagged_records = if @include_descendants
      @section_tag.tagged_records_including_descendants
    else
      @section_tag.tagged_records
    end
  end

  def create
    attributes = section_tag_params
    @section_tag = @story.section_tags.new(attributes)
    return if remember_draft_create(@section_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@section_tag, requested_position: attributes[:position])
        format.json { render json: section_tag_json, status: :created }
      else
        format.json { render json: @section_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /section_tags/1 or /section_tags/1.json
  def update
    attributes = section_tag_params
    return if remember_draft_update(@section_tag, attributes)

    respond_to do |format|
      if update_section_tag(attributes)
        format.json { render json: section_tag_json, status: :ok }
      else
        format.json { render json: @section_tag.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /section_tags/1 or /section_tags/1.json
  def destroy
    return if remember_draft_delete(@section_tag)

    destroy_with_sibling_position(@section_tag)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def set_section_tag
    @section_tag = @story.section_tags.find(params.expect(:id))
  end

  # Positions are maintained among the story's section tags, not the universe's.
  def sibling_collection
    @story.section_tags
  end

  def sibling_position_scope_owner
    @story
  end

  # The canonical index URL for a set of filter values. `FilteredListQuery` owns
  # everything else about reading and carrying the filter, and this is the one
  # thing it cannot know: where this list's own URL is.
  def filtered_list_path_with(query)
    path = universe_story_section_tags_path(story_id: @story)

    query.any? ? "#{path}?#{query.to_query}" : path
  end

  def section_tag_json
    {
      id: @section_tag.id,
      name: @section_tag.name,
      description: @section_tag.description,
      bgcolor: @section_tag.bgcolor,
      fgcolor: @section_tag.fgcolor,
      parent_id: @section_tag.parent_id,
      position: @section_tag.position,
      taggable: @section_tag.taggable,
      url: universe_story_section_tag_path(story_id: @story, id: @section_tag)
    }
  end

  # Only allow a list of trusted parameters through.
  def section_tag_params
    params.expect(section_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable ])
  end

  def update_section_tag(attributes)
    update_with_sibling_position(@section_tag, attributes)
  end
end
