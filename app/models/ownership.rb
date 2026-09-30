class Ownership < ApplicationRecord
  include HasManyTags
  include HasSlug
  include HasPhoto
  include OptionalName
  include SoftDeletable
  include InvalidatesMenuCounts
  include Searchable

  searchable kind: "ownership", title: :display_string, body: :description, route: "ownership"
  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :item
  belongs_to :character
  has_many_tags :ownership_tag, scope: :universe_id

  # Generate before HasSlug so the composite slug can be set on create.
  # Later endpoint or tag changes do not rewrite this creation-time snapshot.
  before_validation :generate_slug, on: :create, prepend: true
  validates :item, :character, presence: true
  validate :associated_records_belong_to_universe

  # An Ownership is a link between a character and an item and its own name is
  # optional, so the two endpoints are the reliable label. Row actions, delete
  # confirmations, and the details page all read this instead of a blank name.
  #
  # Unlike `Relation`, the fallback is a sentence and the verb in it is chrome, so
  # it has two forms. `#display_string` is the **stored** one: it is the model's
  # `searchable title:`, so a search document keeps this string and one index
  # serves every reader, which is why it is resolved in the application's default
  # locale whatever the request is in. `#display_label` is the same phrase in the
  # reader's language, and it is what a view reads. `OwnershipTest` pins the two
  # together, so the stored wording cannot move without the test saying so.
  def display_string
    I18n.with_locale(AppLocale::DEFAULT) { display_label }
  end

  def display_label
    name.presence || I18n.t("ownerships.display_label", character: character&.name, item: item&.name)
  end

  private

  def generate_slug
    return if slug.present?

    if name.present?
      name_slug = slugify(name)
      return self.slug = name_slug if name_slug.present?
    end

    # Tags are optional, so the tag segment may be missing entirely.
    parts = [ character&.slug, ownership_tags.first&.slug, item&.slug ].compact
    self.slug = parts.presence&.join("-") || SecureRandom.hex(4)
  end

  def associated_records_belong_to_universe
    { item: item, character: character }.each do |name, record|
      errors.add(name, I18n.t("ownerships.errors.must_belong_to_universe")) if record && universe && record.universe_id != universe_id
    end
  end
end
