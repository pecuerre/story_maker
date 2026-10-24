# A Scene-level detection or deliberate annotation of one trope from the shared
# reference catalogue. The same trope may have a different context in each use.
class SceneTrope < ApplicationRecord
  belongs_to :scene

  attr_writer :selected

  validates :trope_slug, presence: true, inclusion: { in: TropeCatalog.slugs }
  validates :trope_slug, uniqueness: { scope: :scene_id }
  validates :context_note, length: { maximum: 2000 }

  def selected
    return ActiveModel::Type::Boolean.new.cast(@selected) unless @selected.nil?

    persisted?
  end

  def trope
    TropeCatalog.find(trope_slug)
  end
end
