# Applies one `StoryStructureCatalog` entry to a Story that has no structure yet.
#
# The operation is deliberately narrow: it creates ordinary Sections and Scenes
# through the same `PositionedResourceOrder` service every positional mutation
# uses, so the records pass their models' own validations and land at the end of
# their sequences. It imports no Elements, no prose, and no Universe facts.
#
# **Why the Story must be empty.** A template is a starting shape, not a second
# structure merged into an existing one. Appending a template to a Story that
# already has Sections or Scenes would interleave two shapes with no stated
# order, so the check runs again after the Story row is locked and a concurrent
# second apply is refused rather than duplicated.
#
# **Why draft-based universes are refused by the caller.** A template is many
# creates whose Scenes point at Sections that do not exist until the draft is
# applied, and a remembered change names only one record. The controller refuses
# before calling this service rather than writing through the draft contract;
# see [the feature document](../../docs/features/story_structures.md).
class StoryStructureApplier
  attr_reader :sections, :scenes

  def self.call(story, entry)
    new(story, entry).call
  end

  def initialize(story, entry)
    @story = story
    @entry = entry
    @sections = []
    @scenes = []
  end

  def call
    applied = false

    ApplicationRecord.transaction do
      @story.lock!
      raise ActiveRecord::Rollback if occupied?

      @entry.acts.each do |act|
        section = create_section(act)
        raise ActiveRecord::Rollback unless section

        act.beats.each do |beat|
          raise ActiveRecord::Rollback unless create_scene(section, beat)
        end
      end

      applied = true
    end

    applied
  end

  private
    def occupied?
      @story.sections.exists? || @story.scenes.exists?
    end

    def create_section(act)
      section = @story.sections.new(name: I18n.t(act.name_key))

      if PositionedResourceOrder.create(section, @story.sections, scope_owner: @story, parent_id: nil)
        @sections << section
        section
      end
    end

    def create_scene(section, beat)
      scene = @story.scenes.new(
        name: I18n.t(beat.name_key),
        description: I18n.t(beat.description_key),
        section: section
      )

      if PositionedResourceOrder.create(scene, @story.scenes, scope_owner: @story, parent_id: nil, hierarchical: false)
        @scenes << scene
        scene
      end
    end
end
