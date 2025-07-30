class Taxonomy < ApplicationRecord
  has_many :taxons, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" }
  validates :fixed, inclusion: { in: [ true, false ] }, allow_nil: true

  before_create :set_default_fixed
  after_create :create_root_taxon

  private

  def set_default_fixed
    self.fixed = false if fixed.nil?
  end

  def create_root_taxon
    taxons.create!(name: name, parent: nil)
  end
end
