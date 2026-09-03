class SectionTypesController < ApplicationController
  before_action :set_section_type, only: %i[ show edit update destroy ]

  # GET /section_types/new
  def new
    @section_type = Current.story.section_types.new(parent_id: params[:parent_id])
  end

  # GET /section_types or /section_types.json
  def index
    @section_types = Current.story.section_types
    @section_types = @section_types.includes(:children)
    @section_types = @section_types.where(parent_id: nil).order(:position, :id)
  end

  # POST /section_types or /section_types.json
  def create
    @section_type = Current.story.section_types.new(section_type_params)
    @section_type.position = sibling_count(@section_type.parent_id)

    respond_to do |format|
      if @section_type.save
        format.html {
          redirect_to story_section_type_path(
              story_slug: Current.story.slug,
              id: @section_type
            ),
            notice: "Section type was successfully created."
        }
        format.json {
          render json: {
            id: @section_type.id,
            name: @section_type.name,
            description: @section_type.description,
            parent_id: @section_type.parent_id,
            position: @section_type.position,
            url: story_section_type_path(
              story_slug: Current.story.slug,
              id: @section_type
            )
          },
          status: :created
        }
      else
        format.html {
          render :new, status: :unprocessable_content
        }
        format.json {
          render json: @section_type.errors, status: :unprocessable_content
        }
      end
    end
  end

  # PATCH/PUT /section_types/1 or /section_types/1.json
  def update
    respond_to do |format|
      if update_section_type
        format.html {
          redirect_to story_section_type_path(
            story_slug: Current.story.slug,
            id: @section_type
          ),
          notice: "Section type was successfully updated.",
          status: :see_other
        }
        format.json {
          render json: {
            id: @section_type.id,
            name: @section_type.name,
            description: @section_type.description,
            parent_id: @section_type.parent_id,
            position: @section_type.position,
            url: story_section_type_path(
              story_slug: Current.story.slug,
              id: @section_type
            )
          },
          status: :ok
        }
      else
        format.html {
          render :edit, status: :unprocessable_content
        }
        format.json {
          render json: @section_type.errors, status: :unprocessable_content
        }
      end
    end
  end

  # DELETE /section_types/1 or /section_types/1.json
  def destroy
    @section_type.destroy!

    respond_to do |format|
      format.html {
        redirect_to story_section_types_path(story_slug: Current.story.slug),
          notice: "Section type was successfully destroyed.",
          status: :see_other
        }
      format.json {
        head :no_content
      }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_section_type
      @section_type = Current.story.section_types.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def section_type_params
      params.expect(section_type: [ :name, :description, :parent_id, :position ])
    end

    def sibling_count(parent_id)
      Current.story.section_types.where(parent_id: parent_id).where.not(id: @section_type&.id).count
    end

    def update_section_type
      attributes = section_type_params
      requested_position = attributes[:position]
      old_parent_id = @section_type.parent_id

      return false unless @section_type.update(attributes.except(:position))

      if requested_position.present? || old_parent_id != @section_type.parent_id
        normalize_siblings(Current.story.section_types.where(parent_id: old_parent_id).order(:position, :id).to_a) if old_parent_id != @section_type.parent_id
        siblings = @section_type.sibling_scope.to_a
        position = requested_position.present? ? requested_position.to_i.clamp(0, siblings.length) : siblings.length
        siblings.insert(position, @section_type)
        normalize_siblings(siblings)
      end

      true
    end

    def normalize_siblings(siblings)
      siblings = siblings.to_a unless siblings.respond_to?(:to_a)
      siblings.each_with_index { |section_type, index| section_type.update_columns(position: index) }
    end
end