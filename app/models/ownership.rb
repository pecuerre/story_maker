class Ownership < ApplicationRecord
  include HasManyTypes

  belongs_to :story
  belongs_to :item
  belongs_to :character
  has_many_types :ownership_type

  validates :item, :character, presence: true
  validate :associated_records_belong_to_story

  private

  def associated_records_belong_to_story
    { item: item, character: character }.each do |name, record|
      errors.add(name, "must belong to the ownership's story") if record && story && record.story_id != story_id
    end
    ownership_types.each do |ownership_type|
      next if story.nil? || ownership_type.story_id == story_id

      errors.add(:ownership_types, "must belong to the ownership's story")
    end
  end
end
