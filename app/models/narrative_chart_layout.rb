# Presentation data for the Narrative order chart: where each Scene sits in the
# two columns and the connector that joins its two places. Coordinates are
# computed for each render and never written back to a Scene.
#
# The left column is the Story's one telling order, so a Scene's left index is its
# `position`. The right column holds the same Scenes sorted by the Timeline row of
# the Event that places them, so a crossing connector is a reversal between telling
# and happening — a flashback, a cold open, a parallel thread. The chart claims
# nothing about intent and never calls a crossing an error.
#
# A Scene the Timeline cannot place has no chronological row. It is drawn in a
# separate band at the bottom of the right column, in narrative order, because
# omitting it would make the chart claim the Story has fewer Scenes than it does.
# The band is marked by `separator_y`, a rule the view draws across the column.
class NarrativeChartLayout
  WIDTH = 1000
  BAR_WIDTH = 300
  # The height every Story is compressed towards, in the SVG's own units. A short
  # Story gets roomier bars; a long one shrinks to MIN_PITCH rather than pushing
  # the detail below the fold.
  TARGET_HEIGHT = 560
  MIN_PITCH = 4
  MAX_PITCH = 12
  # The gap between one bar and the next. A bar is never thinner than 2 units, so
  # a Story long enough to reach MIN_PITCH still draws a visible line.
  BAR_INSET = 4
  MIN_BAR_HEIGHT = 2
  CONNECTOR_BEND = 0.42

  # One Scene with the y of its bar in each column and the path between them.
  Entry = Data.define(:row, :left_y, :right_y, :bar_height, :connector, :chronological_position) do
    def scene
      row.scene
    end

    def position
      row.position
    end

    def placed?
      row.placed?
    end
  end

  attr_reader :entries, :width, :height, :pitch, :bar_height,
    :placed_count, :unplaced_count, :separator_y

  def initialize(comparison)
    rows = comparison.rows
    @width = WIDTH
    @pitch = pitch_for(rows.size)
    @bar_height = [ @pitch - BAR_INSET, MIN_BAR_HEIGHT ].max
    @height = rows.size * @pitch
    @placed_count = rows.count(&:placed?)
    @unplaced_count = rows.size - @placed_count
    @separator_y = @pitch * @placed_count if @placed_count.positive? && @unplaced_count.positive?
    @entries = build_entries(rows)
  end

  def left_bar_x
    0
  end

  def bar_width
    BAR_WIDTH
  end

  def right_bar_x
    WIDTH - BAR_WIDTH
  end

  private
    # The narrative order on the left, the chronological order on the right. The
    # two indexes are what a connector joins, so this is the whole of the chart's
    # claim about which Scene is which.
    def build_entries(rows)
      left_index = rows.each_with_index.to_h { |row, index| [ row.scene.id, index ] }
      chronological = rows.select(&:placed?).sort_by { |row| [ row.timeline_row, row.position ] } +
        rows.reject(&:placed?)
      right_index = chronological.each_with_index.to_h { |row, index| [ row.scene.id, index ] }

      rows.map do |row|
        left_y = center_for(left_index.fetch(row.scene.id))
        right_index_for_row = right_index.fetch(row.scene.id)
        right_y = center_for(right_index_for_row)
        Entry.new(row: row, left_y: left_y, right_y: right_y, bar_height: @bar_height,
          connector: connector_path(left_y, right_y),
          chronological_position: right_index_for_row + 1)
      end
    end

    def pitch_for(count)
      return MAX_PITCH if count.zero?

      (TARGET_HEIGHT.to_f / count).floor.clamp(MIN_PITCH, MAX_PITCH)
    end

    def center_for(index)
      ((index * @pitch) + (@pitch / 2.0)).round(2)
    end

    # A cubic with its handles inside the gap, so the line leaves the bar flat and
    # arrives flat. It joins two bars; it never implies a third.
    def connector_path(left_y, right_y)
      left = BAR_WIDTH.to_f
      right = WIDTH - BAR_WIDTH.to_f
      bend = (right - left) * CONNECTOR_BEND

      format("M %.2f %.2f C %.2f %.2f, %.2f %.2f, %.2f %.2f",
        left, left_y, left + bend, left_y, right - bend, right_y, right, right_y)
    end
end
