class Story < ApplicationRecord
  has_many :locations, dependent: :destroy
  has_many :taxonomies, dependent: :destroy
  has_one :location_type_taxonomy, -> { where(slug: "location-types") }, class_name: "Taxonomy"
  has_many :location_type_taxons, through: :location_type_taxonomy, source: :taxons

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug

  after_create :create_fixed_taxonomies

  private

  def create_fixed_taxonomies
    Taxonomy::FIXED_TAXONOMIES.each do |taxonomy_data|
      slug = to_slug(taxonomy_data[:name])

      taxonomies.create!(
        name: taxonomy_data[:name],
        description: taxonomy_data[:description],
        slug: slug,
        fixed: true,
        is_story_taxonomy: taxonomy_data[:is_story_taxonomy],
        is_setting_taxonomy: taxonomy_data[:is_setting_taxonomy],
        default_taxon: taxonomy_data[:default_taxon]
      )
    end
  end
end
