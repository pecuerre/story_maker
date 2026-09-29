# One flat ordered block of a Scene's prose. A Scene can hold any number of
# Elements, including none: an unfinished Scene is valid, so the sequence is
# never required. `kind` is constrained rather than named `type`, because Active
# Record reserves `type` for single-table inheritance.
#
# A Dialogue Element names one or more speaking Characters through the
# `scene_element_speakers` join. The link is a plain many-to-many association
# because it carries no data of its own and records no turn order: it says who
# speaks in the block, not which line belongs to whom. Narration cannot keep
# speakers at all.
class SceneElement < ApplicationRecord
  NARRATION = "narration"
  DIALOGUE = "dialogue"
  KINDS = [ NARRATION, DIALOGUE ].freeze

  include SoftDeletable
  include Searchable

  # A Scene Element has no page of its own — the editor lives under Scene
  # Details — so it declares no route and points a hit at the Scene that owns it.
  searchable kind: "scene_element", title: :name, body: :body, scope: :story

  belongs_to :scene
  # An Element belongs to a Scene, which belongs to a Story. Delegating the step
  # keeps a story-scoped consumer — the search document, the universe resolver —
  # from having to know how deep the Element actually sits.
  delegate :story, to: :scene, allow_nil: true
  # `dependent:` is not an option on a HABTM association; Active Record removes
  # the join rows itself when the owner is destroyed, which is what stops a
  # Dialogue's speakers from outliving it.
  has_and_belongs_to_many :characters, join_table: :scene_element_speakers

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validate :speakers_match_kind
  validate :speaker_assignments_are_valid
  validate :speakers_belong_to_the_scene_universe

  # Active Record's generated collection writer raises when a speaker id is
  # unknown. The Element editor accepts speaker assignments, so an unknown,
  # duplicated, or cross-universe id has to become an ordinary validation error
  # instead of a driver exception. A speaker list that is absent from the
  # request is left alone, so an edit that does not touch the picker keeps the
  # stored speakers.
  def character_ids=(ids)
    requested_ids = Array(ids).filter_map { |id| id.respond_to?(:id) ? id.id : id }
      .compact_blank.map(&:to_s)
    existing_ids = Character.where(id: requested_ids).pluck(:id).map(&:to_s)
    scope_universe_id = scene_universe_id
    scoped_ids = if scope_universe_id.present?
      Character.where(id: requested_ids, universe_id: scope_universe_id).pluck(:id).map(&:to_s)
    else
      # A record built through the Scene association receives its Scene after
      # mass assignment, so the cross-universe check is deferred to
      # `speakers_belong_to_the_scene_universe` rather than failing here.
      existing_ids
    end

    @character_assignment_errors = []
    @character_assignment_errors << "must exist" if (requested_ids - existing_ids).any?
    @character_assignment_errors << "must be unique" if requested_ids.uniq.length != requested_ids.length
    # Only reported when the scene is already known: with no owner yet every
    # existing Character is treated as in scope and re-checked once it is.
    @character_assignment_errors << "must belong to the scene's universe" if scope_universe_id.present? &&
      (existing_ids - scoped_ids).any?

    self.characters = Character.where(id: scoped_ids).to_a
  end

  def universe
    scene&.universe
  end

  # An Element is story-scoped through the Scene that owns it, so it has to say
  # how a reindex finds its records: there is no `story_id` column to filter on.
  def self.search_scope(universe)
    story_ids = universe.stories.select(:id)
    where(scene_id: Scene.where(story_id: story_ids).select(:id))
  end

  # The stored path of a hit is the page a reader lands on, so an Element's hit
  # opens its Scene. `search_document` still carries the Element's own id, so a
  # reindex replaces the document rather than adding a second one.
  def search_url
    Rails.application.routes.url_helpers.universe_story_scene_path(
      universe_slug: story.universe.to_param, story_id: story.id, id: scene_id
    )
  end

  def narration?
    kind == NARRATION
  end

  def dialogue?
    kind == DIALOGUE
  end

  # `Scene` has no `universe_id` of its own: it reaches its Universe through the
  # Story that owns it, so the shared scope is read from there.
  def scene_universe_id
    scene&.universe&.id
  end

  private
    def speaker_assignments_are_valid
      Array(@character_assignment_errors).each do |message|
        errors.add(:character_ids, message)
      end
    end

    def speakers_match_kind
      # A rejected speaker list already explains itself. Adding "a dialogue needs
      # a speaker" on top of "that speaker does not exist" would only be a second
      # way of saying the same thing.
      return if @character_assignment_errors.present?

      if dialogue? && characters.empty?
        errors.add(:character_ids, "is required for a dialogue element")
      elsif narration? && characters.any?
        # The modal offers an explicit "remove the speakers" confirmation, which
        # submits an empty list in the same request. Reaching this message means
        # no such confirmation was given, so the change is refused rather than
        # silently dropping the speakers.
        errors.add(:kind, "cannot be Narration while speakers are still assigned")
      end
    end

    # A speaker is a Character of the Scene's own Universe, checked here as well
    # as in the id writer so a direct association assignment is covered too. No
    # foreign key can prove it: the shared scope lives two joins away.
    def speakers_belong_to_the_scene_universe
      universe_id = scene_universe_id
      return if universe_id.blank?

      characters.each do |character|
        next if character.universe_id == universe_id

        errors.add(:character_ids, "must belong to the scene's universe")
      end
    end
end
