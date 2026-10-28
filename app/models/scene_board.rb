# One Story's Scenes arranged by Section, for the read-only planning board.
#
# A board shows the Story's structure as columns: every Section in the Story's
# own tree order, plus the **Ungrouped** column for Scenes that belong to none.
# Within a column the cards keep `Scene#position`, so the board never introduces
# a second order or regroups the narrative sequence; the grouping is the Section
# each Scene already stores.
#
# This is a read. It builds no form and stores nothing. It reads only the two
# records it draws — the Section tree and the Story's Scenes — so a board does
# not cost the matrix's count queries for numbers no card shows.
class SceneBoard
  # The value a board form sends as `return_to`. The controller recognizes only
  # this destination, so the parameter names a workspace rather than a URL and a
  # hand-edited value falls back to the action's ordinary destination.
  RETURN_TO = "scene_board".freeze

  # One column: a Section, or the ungrouped group when `section` is nil.
  Column = Struct.new(:section, :label, :scenes, keyword_init: true) do
    def ungrouped?
      section.nil?
    end
  end

  attr_reader :story, :scenes, :columns

  def initialize(story)
    @story = story
    sections = story.sections.reorder(:position, :id).to_a
    @paths = SectionPaths.build(sections)
    @scenes = story.scenes.reorder(:position, :id).to_a
    scenes_by_section = @scenes.group_by(&:section_id)
    sections_by_id = sections.index_by(&:id)

    @columns = @paths.ids.map do |section_id|
      section = sections_by_id.fetch(section_id)
      Column.new(
        section: section,
        label: @paths.label_for(section),
        scenes: scenes_by_section.fetch(section.id, [])
      )
    end
    @columns << Column.new(
      section: nil,
      label: @paths.ungrouped_label,
      scenes: scenes_by_section.fetch(nil, [])
    )
  end

  def scenes?
    scenes.any?
  end

  # The first and last narrative positions, for the disabled state of a card's
  # Move controls. They come from the whole sequence, exactly as the list's
  # boundary state does, so a card at either end cannot offer a no-op move.
  def first_position
    scenes.first&.position
  end

  def last_position
    scenes.last&.position
  end

  # The Section selector's options, including the explicit **Ungrouped** choice,
  # built once for the whole board from the same Section index the columns use.
  def grouping_options
    @paths.grouping_options
  end
end
