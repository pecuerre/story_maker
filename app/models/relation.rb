class Relation < ApplicationRecord
  belongs_to :story
  belongs_to :character1, class_name: "Character"
  belongs_to :character2, class_name: "Character"
  belongs_to :relation_type

  validates :character1, :character2, :relation_type, presence: true
  validate :associated_records_belong_to_story

  private

  def associated_records_belong_to_story
    { character1: character1, character2: character2, relation_type: relation_type }.each do |name, record|
      errors.add(name, "must belong to the relation's story") if record && story && record.story_id != story_id
    end
  end
end
