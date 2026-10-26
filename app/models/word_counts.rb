# The prose total for one Story, and its rollup per Section.
#
# A Story's prose lives in two tables (`scene_elements.body` and
# `scene_dialogue_turns.body`), each carrying its own stored `word_count`. This
# value object answers both questions from four fixed queries per Story — the
# Scene-to-Section map, the Section parent map, the Element totals, and the turn
# totals — so no page reads a body to draw a number and no row costs a query of
# its own.
#
# A Section's total includes its **descendant Sections'** Scenes, because a parent
# Section is how a chapter groups its parts: a count that stopped at the parent's
# own Scenes would read as zero for the heading that holds the prose. The Story
# total includes ungrouped Scenes, which belong to no Section at all.
class WordCounts
  def self.for_story(story)
    new(story)
  end

  def initialize(story)
    @story = story
    @by_scene = scene_totals
    @scene_sections = story.scenes.pluck(:id, :section_id).to_h
    @section_parents = story.sections.pluck(:id, :parent_id).to_h
    @by_section = section_totals
  end

  # Every word in the Story's Elements and Dialogue turns, grouped or not.
  def total
    @by_scene.values.sum
  end

  # A Section's own Scenes plus every descendant Section's. A Section that does
  # not belong to this Story has no words here and answers zero.
  def for_section(section_or_id)
    @by_section.fetch(section_id_of(section_or_id), 0)
  end

  private
    # Scenes with nothing written are absent from both grouped results, so the
    # hash starts empty and `total` counts only prose that exists.
    def scene_totals
      totals = Hash.new(0)
      element_totals.each { |scene_id, count| totals[scene_id] += count }
      turn_totals.each { |scene_id, count| totals[scene_id] += count }
      totals
    end

    def element_totals
      SceneElement.where(scene_id: @story.scenes.select(:id)).group(:scene_id).sum(:word_count)
    end

    # The turn table has no `scene_id`, so the group is read one join up. Both
    # default scopes still apply: a soft-deleted Element and its soft-deleted
    # turns are not prose the Story still contains.
    def turn_totals
      SceneDialogueTurn.joins(:scene_element)
        .where(scene_elements: { scene_id: @story.scenes.select(:id) })
        .group("scene_elements.scene_id")
        .sum(:word_count)
    end

    def section_totals
      totals = Hash.new(0)
      @by_scene.each do |scene_id, count|
        next if count.zero?

        section_id = @scene_sections[scene_id]
        add_to_ancestors(totals, section_id, count) if section_id
      end
      totals
    end

    # `seen` stops a corrupt parent cycle from looping; a Section whose parent is
    # not part of this Story ends the walk rather than reading a foreign row.
    def add_to_ancestors(totals, section_id, count)
      seen = {}
      while section_id && @section_parents.key?(section_id) && !seen[section_id]
        seen[section_id] = true
        totals[section_id] += count
        section_id = @section_parents[section_id]
      end
    end

    def section_id_of(section_or_id)
      section_or_id.respond_to?(:id) ? section_or_id.id : section_or_id
    end
end
