class Relation < ApplicationRecord
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :character1, class_name: "Character"
  belongs_to :character2, class_name: "Character"
  has_many_tags :relation_tag

  # Generate before HasSlug so the composite slug can be set on create.
  # Later endpoint or tag changes do not rewrite this creation-time snapshot.
  before_validation :generate_slug, on: :create, prepend: true
  validates :character1, :character2, presence: true
  validate :associated_records_belong_to_universe

  private

  def generate_slug
    return if slug.present?

    if name.present?
      name_slug = slugify(name)
      return self.slug = name_slug if name_slug.present?
    end

    # Tags are optional, so the tag segment may be missing entirely.
    parts = [ character1&.slug, relation_tags.first&.slug, character2&.slug ].compact
    self.slug = parts.presence&.join("-") || SecureRandom.hex(4)
  end

  def associated_records_belong_to_universe
    { character1: character1, character2: character2 }.each do |name, record|
      errors.add(name, "must belong to the relation's universe") if record && universe && record.universe_id != universe_id
    end
    relation_tags.each do |relation_tag|
      next if universe.nil? || relation_tag.universe_id == universe_id

      errors.add(:relation_tags, "must belong to the relation's universe")
    end
  end
end
