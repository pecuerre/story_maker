class RelationsController < ApplicationController
  before_action :set_relation, only: %i[ update destroy ]

  def index
    load_form_options
    @relations = Current.story.relations.includes(:character1, :character2, :relation_types).order(:id)
  end

  def create
    @relation = Current.story.relations.new(relation_params)

    if @relation.save
      redirect_to story_relations_path(), notice: "Relation created."
    else
      load_form_options
      @relations = Current.story.relations.includes(:character1, :character2, :relation_types).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @relation.update(relation_params)
      redirect_to story_relations_path(), notice: "Relation updated."
    else
      load_form_options
      @relations = Current.story.relations.includes(:character1, :character2, :relation_types).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @relation.destroy!
    redirect_to story_relations_path(), notice: "Relation deleted."
  end

  private

  def set_relation
    @relation = Current.story.relations.find(params.expect(:id))
  end

  def relation_params
    params.expect(relation: [ :character1_id, :character2_id, { relation_type_ids: [] }, :description, :from_date, :to_date ])
  end

  def load_form_options
    @characters = Current.story.characters.order(:name, :id)
    @relation_types = Current.story.relation_types.order(:name, :id)
  end
end
