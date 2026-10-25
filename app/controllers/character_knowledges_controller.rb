class CharacterKnowledgesController < ApplicationController
  include DraftMutation

  before_action :set_character
  before_action :set_knowledge, only: %i[ update destroy ]

  def create
    @knowledge = Current.universe.character_knowledges.new(knowledge_params.merge(character: @character))
    attributes = knowledge_params.to_h.merge(character_id: @character.id)
    return if remember_draft_create(@knowledge, attributes)

    if @knowledge.save
      redirect_to character_path, notice: t("characters.knowledge.created")
    else
      render_character_details(status: :unprocessable_content)
    end
  end

  def update
    attributes = knowledge_params
    return if remember_draft_update(@knowledge, attributes)

    if @knowledge.update(attributes)
      redirect_to character_path, notice: t("characters.knowledge.updated"), status: :see_other
    else
      render_character_details(status: :unprocessable_content)
    end
  end

  def destroy
    return if remember_draft_delete(@knowledge)

    @knowledge.soft_delete
    redirect_to character_path, notice: t("characters.knowledge.deleted"), status: :see_other
  end

  private

  def set_character
    @character = Current.universe.characters.find(params.expect(:character_id))
  end

  def set_knowledge
    @knowledge = @character.character_knowledges.find(params.expect(:id))
  end

  def knowledge_params
    params.expect(character_knowledge: [ :when_text, :what_learned, :source_character_id, :changes_plan ])
  end

  def character_path
    universe_character_path(universe_slug: Current.universe.slug, id: @character)
  end

  def render_character_details(status:)
    @character_knowledges = @character.character_knowledges.includes(:source_character).order(:created_at, :id)
    @knowledge ||= Current.universe.character_knowledges.new(character: @character)
    render "characters/show", status: status
  end
end
