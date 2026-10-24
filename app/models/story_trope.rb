# A Story-level detection or deliberate annotation of one trope from the shared
# reference catalogue. Its note belongs to this use, not to the trope globally.
class StoryTrope < ApplicationRecord
  belongs_to :story

  attr_writer :selected

  validates :trope_slug, presence: true, inclusion: { in: TropeCatalog.slugs }
  validates :trope_slug, uniqueness: { scope: :story_id }
  validates :context_note, length: { maximum: 2000 }

  def selected
    return ActiveModel::Type::Boolean.new.cast(@selected) unless @selected.nil?

    persisted?
  end

  def trope
    TropeCatalog.find(trope_slug)
  end
end
