# A Scene is one narrative unit inside a Story. Stories own the ordered scene
# sequence; universe-level world records stay shared and are linked to a scene
# in later slices. The sequence is flat: `position` expresses narrative order,
# not in-world chronology, and is maintained by PositionedResourceOrder.
class Scene < ApplicationRecord
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :story, cache_scope: Story::SCENE_MENU_COUNT_SCOPE

  belongs_to :story
  # Section is optional organizational grouping only. A nested Section also
  # places the Scene inside that Section's ancestor path; it is not a second
  # stored membership, and it never changes the narrative position.
  belongs_to :section, optional: true
  # The Event is an optional shared in-world fact, not the Scene's identity.
  # Several Scenes may reference the same Event.
  belongs_to :event, optional: true

  validates :name, presence: true
  validate :optional_references_exist
  validate :section_belongs_to_story
  validate :event_belongs_to_story_universe
  validate :datetime_is_a_valid_point

  def universe
    story&.universe
  end

  private
    # Shared scopes are application-level rules: a real foreign key cannot prove
    # that a Section belongs to this Scene's Story or that an Event belongs to
    # this Story's Universe.
    def section_belongs_to_story
      return if section.nil? || story.nil?
      return if section.story_id == story_id

      errors.add(:section, "must belong to the same story")
    end

    def event_belongs_to_story_universe
      return if event.nil? || story&.universe.nil?
      return if event.universe_id == story.universe_id

      errors.add(:event, "must belong to the story's universe")
    end

    # An unknown optional ID would otherwise raise a foreign-key exception (a
    # 500) instead of rendering a field error.
    def optional_references_exist
      errors.add(:section, "must exist") if section_id.present? && section.nil?
      errors.add(:event, "must exist") if event_id.present? && event.nil?
    end

    # Active Record casts an unparseable datetime to nil, which would silently
    # discard the author's input. Reject it as an ordinary validation error so
    # the value is never dropped without an explanation.
    def datetime_is_a_valid_point
      return unless new_record? || will_save_change_to_datetime?

      submitted = read_attribute_before_type_cast(:datetime)
      return if submitted.blank? || datetime.present?

      errors.add(:datetime, "is not a valid date and time")
    end
end
