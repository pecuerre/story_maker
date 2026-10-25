class CharacterKnowledge < ApplicationRecord
  include SoftDeletable

  belongs_to :universe
  belongs_to :character
  belongs_to :source_character, class_name: "Character", optional: true

  validates :when_text, presence: true
  validates :what_learned, presence: true
  validate :references_belong_to_same_universe
  before_validation :inherit_universe_from_character

  def universe
    super || character&.universe
  end

  private

  def inherit_universe_from_character
    self.universe ||= character&.universe
  end

  def references_belong_to_same_universe
    if character && character.universe_id != universe_id
      errors.add(:character, I18n.t("shared.errors.same_scope.universe"))
    end

    return unless source_character && source_character.universe_id != universe_id

    errors.add(:source_character, I18n.t("shared.errors.same_scope.universe"))
  end
end
