# A Scene is one narrative unit inside a Story. Stories own the ordered scene
# sequence; universe-level world records stay shared and are linked to a scene
# in later slices. The sequence is flat: `position` expresses narrative order,
# not in-world chronology, and is maintained by PositionedResourceOrder.
class Scene < ApplicationRecord
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :story, cache_scope: Story::SCENE_MENU_COUNT_SCOPE

  belongs_to :story
  has_many_tags :scene_tag, scope: :story_id
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
  validate :scene_tag_assignments_are_valid

  # Active Record's generated collection-id writer raises when an optional tag id
  # is unknown. Scene Details accepts optional tag assignments, so turn that
  # input into ordinary validation errors instead of a global 404/500. Existing
  # ids outside this Story are reported with the same shared-scope message as
  # the HasManyTags validation; duplicate ids are rejected before the database
  # uniqueness index can turn them into a driver error.
  def scene_tag_ids=(ids)
    requested_ids = Array(ids).filter_map { |id| id.respond_to?(:id) ? id.id : id }
      .compact_blank.map(&:to_s)
    normalized_ids = requested_ids.uniq
    existing_ids = SceneTag.where(id: requested_ids).pluck(:id).map(&:to_s)
    scope_story_id = story_id || story&.id
    scoped_ids = if scope_story_id.present?
      SceneTag.where(id: requested_ids, story_id: scope_story_id).pluck(:id).map(&:to_s)
    else
      # An association-built record may receive its Story immediately after
      # mass assignment. Defer the cross-scope check to HasManyTags once that
      # owner is known instead of treating every existing tag as foreign here.
      existing_ids
    end

    @scene_tag_assignment_errors = []
    @scene_tag_assignment_errors << "must exist" if (requested_ids - existing_ids).any?
    @scene_tag_assignment_errors << "must belong to the same story" if (existing_ids - scoped_ids).any?
    @scene_tag_assignment_errors << "must be unique" if normalized_ids.length != requested_ids.length

    self.scene_tags = SceneTag.where(id: scoped_ids).to_a
  end

  def universe
    story&.universe
  end

  private
    def scene_tag_assignments_are_valid
      Array(@scene_tag_assignment_errors).each do |message|
        errors.add(:scene_tags, message)
      end
    end

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
