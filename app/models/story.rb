class Story < ApplicationRecord
  include HasSlug

  belongs_to :universe
  has_many :sections, dependent: :destroy
  has_many :section_tags, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :universe_id }
  validates :slug, uniqueness: { scope: :universe_id }

  # The tag a section gets when its creator picked none. Created on first use:
  # a story starts out without any section tag, and inline section creation
  # sends no tag ids at all.
  def default_section_tag
    section_tags.order(:id).first || section_tags.create!(name: "Section")
  end
end
