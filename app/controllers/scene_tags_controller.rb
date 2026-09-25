class SceneTagsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  include MaintainsSiblingPositions
  maintains_sibling_positions_for :scene_tag

  before_action :set_story
  before_action :set_scene_tag, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def new
    @scene_tag = @story.scene_tags.new(parent_id: params[:parent_id])
  end

  def index
    @scene_tags = @story.scene_tags
      .includes(:children)
      .where(parent_id: nil)
      .order(:position, :id)
    @tagged_counts = TaggedRecordCounts.for(@story.scene_tags)
  end

  # GET /scene_tags/:id — the tag's own details page: the records that carry it.
  # The taxonomy tree links here with that count.
  def show
    @tagged_records = @scene_tag.tagged_records
  end

  def create
    attributes = scene_tag_params
    @scene_tag = @story.scene_tags.new(attributes)

    respond_to do |format|
      if create_with_sibling_position(@scene_tag, requested_position: attributes[:position])
        format.json { render json: scene_tag_json, status: :created }
      else
        format.json { render json: @scene_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if update_scene_tag
        format.json { render json: scene_tag_json, status: :ok }
      else
        format.json { render json: @scene_tag.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    destroy_with_sibling_position(@scene_tag)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private
    # Reject a non-JSON mutation before the positioned service runs. Otherwise a
    # 406 response could be returned only after a record had already committed.
    def require_json_mutation_format
      head :not_acceptable unless request.format.json?
    end

    def set_story
      @story = Current.universe.stories.find(params.expect(:story_id))
    end

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
      params.expect(scene_tag: [ :name, :description, :bgcolor, :fgcolor, :parent_id, :position ])
    end

    def update_scene_tag
      attributes = scene_tag_params
      update_with_sibling_position(@scene_tag, attributes)
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
        url: universe_story_scene_tag_path(story_id: @story, id: @scene_tag)
      }
    end
end
