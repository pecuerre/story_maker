class Relation < ApplicationRecord
  include HasManyTypes

  belongs_to :story
  belongs_to :character1, class_name: "Character"
  belongs_to :character2, class_name: "Character"
  has_many_types :relation_type

  validates :character1, :character2, presence: true
  validate :associated_records_belong_to_story

  private

  def associated_records_belong_to_story
    { character1: character1, character2: character2 }.each do |name, record|
      errors.add(name, "must belong to the relation's story") if record && story && record.story_id != story_id
    end
    relation_types.each do |relation_type|
      next if story.nil? || relation_type.story_id == story_id

      errors.add(:relation_types, "must belong to the relation's story")
    end
  end
end
