class SceneTagsController < ApplicationController
  include PhotoParams
  include MaintainsSiblingPositions
  include RequiresJsonMutationFormat
  include DraftMutation
  include FilteredListQuery

  allow_unauthenticated_access only: %i[ index show ]
  maintains_sibling_positions_for :scene_tag

  # The filter rides along with the index. A tree keeps its drag order and
  # offers no reader sort, so `index` is the only action that reads the filter.
  filters_list_with SceneTagFilter, only: %i[ index ]

  before_action :set_story
  before_action :set_scene_tag, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    @list_filter = SceneTagFilter.new(@filter_query)
    # A GET form submits every field, so the ones the author left alone arrive
    # blank. Redirecting once to the canonical query keeps the address bar, a
    # bookmark, and a shared link limited to the filters really in effect.
    return redirect_to_canonical_filtered_list if blank_filter_values?

    # One query for the whole taxonomy, and the index the tree descends through.
    # `includes(:children)` used to reach the first level only, and the photo is
    # read for every node because the editor carries its stored image.
    @hierarchy = HierarchyIndex.build(@list_filter.apply(
      @story.scene_tags.includes(:photo)))
    @scene_tags = @hierarchy.roots
    @tagged_counts = TaggedRecordCounts.for(@story.scene_tags)
    # The total is read only when a filter is really in effect, so the ordinary
    # unfiltered visit costs no extra query for it.
    @scene_tag_total = @story.scene_tags.count if @list_filter.narrowed?
    flash_discarded_filter_values
  end

  # GET /scene_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    @include_descendants = params[:include_descendants] != "0"
    @tagged_records = if @include_descendants
      @scene_tag.tagged_records_including_descendants
    else
      @scene_tag.tagged_records
    end
  end

  def create
    attributes = scene_tag_params
    @scene_tag = @story.scene_tags.new(attributes)
    return if remember_draft_create(@scene_tag, attributes)

    respond_to do |format|
      if create_with_sibling_position(@scene_tag, requested_position: attributes[:position])
        format.json { render json: scene_tag_json, status: :created }
      else
        format.json { render json: @scene_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = scene_tag_params
    return if remember_draft_update(@scene_tag, attributes)

    respond_to do |format|
      if update_scene_tag(attributes)
        format.json { render json: scene_tag_json, status: :ok }
      else
        format.json { render json: @scene_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@scene_tag)

    destroy_with_sibling_position(@scene_tag)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private
    def set_scene_tag
      @scene_tag = @story.scene_tags.find(params.expect(:id))
    end

    # Positions are maintained among this Story's Scene Tags, not the Universe's
    # or another Story's taxonomy.
    def sibling_collection
      @story.scene_tags
    end

    def sibling_position_scope_owner
      @story
    end

    def scene_tag_params
      params.expect(scene_tag: [ *photo_params, :name, :description, :bgcolor, :fgcolor, :parent_id, :position, :taggable ])
    end

    def update_scene_tag(attributes)
      update_with_sibling_position(@scene_tag, attributes)
    end

    # The canonical index URL for a set of filter values. `FilteredListQuery` owns
    # everything else about reading and carrying the filter, and this is the one
    # thing it cannot know: where this list's own URL is.
    def filtered_list_path_with(query)
      path = universe_story_scene_tags_path(story_id: @story)

      query.any? ? "#{path}?#{query.to_query}" : path
    end

    def scene_tag_json
      {
        id: @scene_tag.id,
        name: @scene_tag.name,
        description: @scene_tag.description,
        bgcolor: @scene_tag.bgcolor,
        fgcolor: @scene_tag.fgcolor,
        parent_id: @scene_tag.parent_id,
        position: @scene_tag.position,
        taggable: @scene_tag.taggable,
        url: universe_story_scene_tag_path(story_id: @story, id: @scene_tag)
      }
    end
end
