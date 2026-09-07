class Ownership < ApplicationRecord
  belongs_to :story
  belongs_to :item
  belongs_to :character
  belongs_to :ownership_type

  validates :item, :character, :ownership_type, presence: true
  validate :associated_records_belong_to_story

  private

  def associated_records_belong_to_story
    { item: item, character: character, ownership_type: ownership_type }.each do |name, record|
      errors.add(name, "must belong to the ownership's story") if record && story && record.story_id != story_id
    end
  end
end
