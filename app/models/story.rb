class Story < ApplicationRecord
  has_many :locations, dependent: :destroy
  has_many :taxonomies, dependent: :destroy

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
        story_taxonomy: taxonomy_data[:story_taxonomy],
        setting_taxonomy: taxonomy_data[:setting_taxonomy]
      )
    end
  end
end
