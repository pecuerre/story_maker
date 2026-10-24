class PlotsController < ApplicationController
  include RequiresJsonMutationFormat
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_story
  before_action :set_plot, only: %i[ show update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  def index
    @plots = @story.plots.order(:name, :id).to_a
    @scene_counts = Plot.scene_counts_by_story(@story)
  end

  def show
    @scenes = @plot.scenes.includes(:section).reorder(:position, :id).to_a
    @section_paths = SectionPaths.build(@story.sections.order(:position, :id).to_a)
    @scene_total = @story.scenes.count
  end

  def create
    attributes = plot_params
    @plot = @story.plots.new(attributes)
    return if remember_draft_create(@plot, attributes)

    respond_to do |format|
      if @plot.save
        format.json { render json: plot_json, status: :created }
      else
        format.json { render json: @plot.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    attributes = plot_params
    return if remember_draft_update(@plot, attributes)

    respond_to do |format|
      if @plot.update(attributes)
        format.json { render json: plot_json, status: :ok }
      else
        format.json { render json: @plot.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    return if remember_draft_delete(@plot)

    @plot.soft_delete
    head :no_content
  end

  private

  def set_plot
    @plot = @story.plots.find(params.expect(:id))
  end

  def plot_params
    params.expect(plot: [ :name, :description ])
  end

  def plot_json
    {
      id: @plot.id,
      name: @plot.name,
      description: @plot.description,
      url: universe_story_plot_path(story_id: @story, id: @plot)
    }
  end
end
