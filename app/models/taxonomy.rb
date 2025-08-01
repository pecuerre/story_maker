class Taxonomy < ApplicationRecord
  belongs_to :story, optional: true
  has_many :taxons, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" }
  validates :fixed, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :is_story_taxonomy, inclusion: { in: [ true, false ] }, allow_nil: true
  validates :is_setting_taxonomy, inclusion: { in: [ true, false ] }, allow_nil: true

  # Uniqueness validation for name and slug within the same story (or global if no story)
  validates :name, uniqueness: { scope: :story_id }
  validates :slug, uniqueness: { scope: :story_id }

  before_create :set_defaults
  after_create :create_root_taxon

  # Fixed taxonomies that are mandatory for every story
  FIXED_TAXONOMIES = [
    {
      name: "Location Types",
      slug: "location-types",
      description: "Types of locations in the story world",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: nil
    },
    {
      name: "World Regions",
      slug: "world-regions",
      description: "Geographic regions and areas in the story world",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: "world"
    },
    {
      name: "Character Class",
      slug: "character-class",
      description: "Professions, classes, or roles of characters",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: nil
    },
    {
      name: "Character Traits",
      slug: "character-traits",
      description: "Personality traits and characteristics of characters",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: nil
    },
    {
      name: "Character Types",
      slug: "character-types",
      description: "Types of characters in the story",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: "human"
    },
    {
      name: "Time Periods",
      slug: "time-periods",
      description: "Historical periods and eras in the story",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: nil
    },
    {
      name: "Event Types",
      slug: "event-types",
      description: "Types of events that can occur in the story",
      is_story_taxonomy: false,
      is_setting_taxonomy: true,
      default_taxon: nil
    }
  ] # .freeze

  def to_param
    slug
  end

  def fixed?
    fixed == true
  end

  def is_story_taxonomy?
    is_story_taxonomy == true
  end

  def is_setting_taxonomy?
    is_setting_taxonomy == true
  end

  private

  def set_defaults
    self.fixed = false if fixed.nil?
    self.is_story_taxonomy = false if is_story_taxonomy.nil?
    self.is_setting_taxonomy = false if is_setting_taxonomy.nil?
  end

  def create_root_taxon
    return unless self.default_taxon.present?
    taxons.create!(name: self.default_taxon, parent: nil)
  end
end
