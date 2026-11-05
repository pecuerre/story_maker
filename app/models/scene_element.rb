# One flat ordered block of a Scene's prose. A Scene can hold any number of
# Elements, including none: an unfinished Scene is valid, so the sequence is
# never required. `kind` is constrained rather than named `type`, because Active
# Record reserves `type` for single-table inheritance.
#
# A Dialogue's cast is its ordered `SceneDialogueTurn` rows: each saved line names
# the Character who speaks it. There is no separate block-level speaker list, so
# the cast cannot disagree with the lines it describes. Narration has neither
# turns nor speakers.
class SceneElement < ApplicationRecord
  NARRATION = "narration"
  DIALOGUE = "dialogue"
  KINDS = [ NARRATION, DIALOGUE ].freeze

  include SoftDeletable
  include OrderedSequence
  include Searchable
  include HasDiscussion
  include WordCountable

  # `WordCounts` sums this stored column for a Story and its Sections, so the
  # count follows Content on every save instead of being derived per page.
  counts_words_from :body

  # An Element's turns cascade with it: soft-deleting the Element soft-deletes
  # its turns, and restoring the Element restores them.
  soft_deletes :scene_dialogue_turns

  # A Scene Element has no page of its own — the editor lives under Scene
  # Details — so it declares no route and points a hit at the Scene that owns it.
  searchable kind: "scene_element", title: :name, body: :body, scope: :story
  # The Scene's one flat sequence, maintained by `SceneElementsController` through
  # `PositionedResourceOrder` and repaired here for a write that reaches the model
  # directly.
  ordered_sequence_within :scene

  belongs_to :scene
  # An Element belongs to a Scene, which belongs to a Story. Delegating the step
  # keeps a story-scoped consumer — the search document, the universe resolver —
  # from having to know how deep the Element actually sits.
  delegate :story, to: :scene, allow_nil: true
  # A turn belongs to its Element and never outlives it: deleting an Element
  # soft-deletes its turns, and a shared Character it named always survives.
  has_many :scene_dialogue_turns, class_name: "SceneDialogueTurn", dependent: :destroy, inverse_of: :scene_element

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validate :turns_match_kind

  def universe
    scene&.universe
  end

  # An Element is story-scoped through the Scene that owns it, so it has to say
  # how a reindex finds its records: there is no `story_id` column to filter on.
  def self.search_scope(universe)
    story_ids = universe.stories.select(:id)
    where(scene_id: Scene.where(story_id: story_ids).select(:id))
  end

  # The same two joins, asked one level down: a story rename reaches its Elements
  # through their Scenes, and a scene rename reaches them directly.
  def self.search_scope_for_story(story)
    where(scene_id: Scene.where(story_id: story.id).select(:id))
  end

  def self.search_scope_for_scene(scene)
    where(scene_id: scene.id)
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

  private
    def turns_match_kind
      return unless narration? && scene_dialogue_turns.with_deleted.exists?

      errors.add(:kind, I18n.t("scenes.element_errors.narration_with_turns"))
    end
end
