class SectionTypesController < ApplicationController
  before_action :set_section_type, only: %i[ show edit update destroy ]

  # GET /section_types or /section_types.json
  def index
    @section_types = []
  end

  # GET /section_types/1 or /section_types/1.json
  def show
  end

  # GET /section_types/new
  def new
    @section_type = SectionType.new
  end

  # GET /section_types/1/edit
  def edit
  end

  # POST /section_types or /section_types.json
  def create
    @section_type = SectionType.new(section_type_params)

    respond_to do |format|
      if @section_type.save
        format.html { redirect_to @section_type, notice: "Section type was successfully created." }
        format.json { render :show, status: :created, location: @section_type }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @section_type.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /section_types/1 or /section_types/1.json
  def update
    respond_to do |format|
      if @section_type.update(section_type_params)
        format.html { redirect_to @section_type, notice: "Section type was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @section_type }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @section_type.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /section_types/1 or /section_types/1.json
  def destroy
    @section_type.destroy!

    respond_to do |format|
      format.html { redirect_to section_types_path, notice: "Section type was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_section_type
      @section_type = SectionType.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def section_type_params
      params.expect(section_type: [ :story_id, :name, :parent_id ])
    end
end