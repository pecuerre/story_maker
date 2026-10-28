class CanonRulesController < ApplicationController
  include DraftMutation

  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_canon_rule, only: %i[ show update destroy ]

  def index
    load_canon_rules
  end

  def show
  end

  def create
    attributes = canon_rule_params
    @canon_rule = Current.universe.canon_rules.new(attributes)
    return if remember_draft_create(@canon_rule, attributes)

    if @canon_rule.save
      redirect_to universe_canon_rules_path, notice: t("canon_rules.flash.created")
    else
      load_canon_rules
      render :index, status: :unprocessable_content
    end
  end

  def update
    attributes = canon_rule_params
    return if remember_draft_update(@canon_rule, attributes)

    if @canon_rule.update(attributes)
      redirect_to universe_canon_rules_path, notice: t("canon_rules.flash.updated"), status: :see_other
    else
      load_canon_rules
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    return if remember_draft_delete(@canon_rule)

    @canon_rule.soft_delete
    redirect_to universe_canon_rules_path, notice: t("canon_rules.flash.deleted"), status: :see_other
  end

  private

  def load_canon_rules
    @stories = Current.universe.stories.order(:name, :id)
    # Universe-wide rules first, then each story's, because the universe's own
    # rules are what every story shares.
    @canon_rules = Current.universe.canon_rules.includes(:story).order(:story_id, :statement)
  end

  def set_canon_rule
    @canon_rule = Current.universe.canon_rules.find(params.expect(:id))
  end

  def canon_rule_params
    params.expect(canon_rule: [ :statement, :source, :story_id ])
  end
end
