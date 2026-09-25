class RelationsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  before_action :set_relation, only: %i[ show update destroy ]

  def index
    load_form_options
    @relations = Current.universe.relations.includes(:character1, :character2, :relation_tags).order(:id)
  end

  # GET /relations/:id — the record's own read-only details page. It identifies the
  # record and is the destination of every "Details" link; later slices add
  # the related-records sections without changing this URL.
  def show
  end

  def create
    @relation = Current.universe.relations.new(relation_params)

    if @relation.save
      redirect_to universe_relations_path(), notice: "Relation created."
    else
      load_form_options
      @relations = Current.universe.relations.includes(:character1, :character2, :relation_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @relation.update(relation_params)
      redirect_to universe_relations_path(), notice: "Relation updated."
    else
      load_form_options
      @relations = Current.universe.relations.includes(:character1, :character2, :relation_tags).order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @relation.destroy!
    redirect_to universe_relations_path(), notice: "Relation deleted."
  end

  private

  def set_relation
    @relation = Current.universe.relations.find(params.expect(:id))
  end

  def relation_params
    params.expect(relation: [ :character1_id, :character2_id, { relation_tag_ids: [] }, :description, :from_date, :to_date ])
  end

  def load_form_options
    @characters = Current.universe.characters.order(:name, :id)
    @relation_tags = Current.universe.relation_tags.order(:name, :id)
  end
end
