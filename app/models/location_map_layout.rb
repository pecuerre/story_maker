# Derives a left-to-right diagram from one Universe's Location tree and Routes.
# The result is presentation data only: coordinates are computed for each render
# and never written back to Location or Route.
class LocationMapLayout
  CARD_WIDTH = 220
  MIN_CARD_HEIGHT = 58
  CARD_PADDING_Y = 20
  LINE_HEIGHT = 18
  MAX_LABEL_CHARACTERS = 24
  COLUMN_GAP = 100
  ROW_GAP = 22
  ROOT_GAP = 30
  GUTTER = 28
  ROUTE_MARGIN = 48
  ROUTE_LANE_GAP = 14
  MIN_WIDTH = 720
  MIN_HEIGHT = 140

  Node = Data.define(:location, :x, :y, :width, :height, :depth, :label_lines) do
    def right
      x + width
    end

    def bottom
      y + height
    end

    def center_x
      x + (width / 2.0)
    end

    def center_y
      y + (height / 2.0)
    end
  end

  Edge = Data.define(:record, :source, :target, :path, :kind)

  attr_reader :nodes, :hierarchy_edges, :route_edges, :width, :height

  def initialize(locations:, routes:)
    @locations = locations.to_a.sort_by { |location| [ location.position, location.id ] }
    @routes = routes.to_a.sort_by(&:id)
    @locations_by_id = @locations.index_by(&:id)
    @children_by_parent = @locations.group_by(&:parent_id)
    @label_lines = @locations.to_h { |location| [ location.id, wrap_label(location.name) ] }
    @subtree_heights = {}
    @nodes_by_id = {}

    position_tree
    @nodes = @nodes_by_id.values.compact.sort_by { |node| [ node.depth, node.y, node.location.id ] }
    @hierarchy_edges = build_hierarchy_edges
    @route_edges = build_route_edges
    set_dimensions
  end

  private

    def position_tree
      cursor = GUTTER
      roots = @children_by_parent[nil] || []

      roots.each do |root|
        cursor += place(root, depth: 0, top: cursor)
        cursor += ROOT_GAP
      end

      # The model rejects cycles and cross-universe parents. Keep orphaned rows
      # visible as roots if raw/imported data bypassed those validations.
      @locations.each do |location|
        next if @nodes_by_id.key?(location.id)

        cursor += place(location, depth: 0, top: cursor)
        cursor += ROOT_GAP
      end

      @tree_bottom = [ cursor - ROOT_GAP + GUTTER, GUTTER + MIN_CARD_HEIGHT ].max
    end

    def place(location, depth:, top:)
      return 0 if @nodes_by_id.key?(location.id)

      # A placeholder breaks a cycle while descendants are laid out.
      @nodes_by_id[location.id] = nil
      children = children_of(location).reject { |child| @nodes_by_id.key?(child.id) }
      children_height = children.sum { |child| subtree_height(child) } + [ children.length - 1, 0 ].max * ROW_GAP
      subtree = [ subtree_height(location), children_height ].max
      child_top = top + ((subtree - children_height) / 2.0)
      child_centers = []

      children.each do |child|
        child_height = place(child, depth: depth + 1, top: child_top)
        child_centers << (child_top + (child_height / 2.0))
        child_top += child_height + ROW_GAP
      end

      node_height = card_height(location)
      center = if child_centers.any?
        (child_centers.first + child_centers.last) / 2.0
      else
        top + (subtree / 2.0)
      end

      @nodes_by_id[location.id] = Node.new(
        location: location,
        x: GUTTER + (depth * (CARD_WIDTH + COLUMN_GAP)),
        y: (center - (node_height / 2.0)).round(2),
        width: CARD_WIDTH,
        height: node_height,
        depth: depth,
        label_lines: @label_lines.fetch(location.id)
      )

      subtree
    end

    def subtree_height(location, ancestors = Set.new)
      return card_height(location) if ancestors.include?(location.id)
      return @subtree_heights[location.id] if @subtree_heights.key?(location.id)

      children = children_of(location)
      next_ancestors = ancestors.dup.add(location.id)
      child_height = children.sum { |child| subtree_height(child, next_ancestors) } + [ children.length - 1, 0 ].max * ROW_GAP
      @subtree_heights[location.id] = [ card_height(location), child_height ].max
    end

    def children_of(location)
      @children_by_parent[location.id] || []
    end

    def card_height(location)
      [ MIN_CARD_HEIGHT, CARD_PADDING_Y + (@label_lines.fetch(location.id).length * LINE_HEIGHT) ].max
    end

    def wrap_label(value)
      words = value.to_s.split
      return [ "" ] if words.empty?

      lines = []
      current = ""
      words.each do |word|
        chunks = word.chars.each_slice(MAX_LABEL_CHARACTERS).map(&:join)
        chunks.each do |chunk|
          if current.present? && (current.length + chunk.length + 1) > MAX_LABEL_CHARACTERS
            lines << current
            current = ""
          end

          current = [ current, chunk ].compact_blank.join(" ")
          if current.length >= MAX_LABEL_CHARACTERS
            lines << current
            current = ""
          end
        end
      end
      lines << current if current.present?
      lines
    end

    def build_hierarchy_edges
      @locations.filter_map do |location|
        parent = @locations_by_id[location.parent_id]
        source = @nodes_by_id[parent&.id]
        target = @nodes_by_id[location.id]
        next unless source && target

        Edge.new(record: location, source: source, target: target,
          path: hierarchy_path(source, target), kind: :hierarchy)
      end
    end

    def hierarchy_path(source, target)
      start_x = source.right
      end_x = target.x
      middle_x = (start_x + end_x) / 2.0

      "M #{coordinate(start_x)} #{coordinate(source.center_y)} " \
        "H #{coordinate(middle_x)} V #{coordinate(target.center_y)} H #{coordinate(end_x)}"
    end

    def build_route_edges
      @routes.each_with_index.filter_map do |route, index|
        source = @nodes_by_id[route.from_location_id]
        target = @nodes_by_id[route.to_location_id]
        next unless source && target

        Edge.new(record: route, source: source, target: target,
          path: route_path(source, target, index), kind: :route)
      end
    end

    def route_path(source, target, index)
      lane = (index + 1) * ROUTE_LANE_GAP
      source_y = source.center_y
      target_y = target.center_y

      if source.location.id == target.location.id
        start_x = source.right
        outside_x = start_x + ROUTE_MARGIN + (index * ROUTE_LANE_GAP)
        start_y = source_y - 8
        end_y = source_y + 8
        return "M #{coordinate(start_x)} #{coordinate(start_y)} " \
          "C #{coordinate(outside_x)} #{coordinate(start_y - lane)} " \
          "#{coordinate(outside_x)} #{coordinate(end_y + lane)} " \
          "#{coordinate(start_x)} #{coordinate(end_y)}"
      end

      if source.x == target.x
        start_x = source.right
        end_x = target.right
        outside_x = start_x + ROUTE_MARGIN + (index * ROUTE_LANE_GAP)
        return "M #{coordinate(start_x)} #{coordinate(source_y)} " \
          "C #{coordinate(outside_x)} #{coordinate(source_y + lane)} " \
          "#{coordinate(outside_x)} #{coordinate(target_y + lane)} " \
          "#{coordinate(end_x)} #{coordinate(target_y)}"
      end

      if source.x < target.x
        start_x = source.right
        end_x = target.x
        control_gap = [ (end_x - start_x) * 0.45, 24 ].max
        "M #{coordinate(start_x)} #{coordinate(source_y)} " \
          "C #{coordinate(start_x + control_gap)} #{coordinate(source_y + lane)} " \
          "#{coordinate(end_x - control_gap)} #{coordinate(target_y + lane)} " \
          "#{coordinate(end_x)} #{coordinate(target_y)}"
      else
        start_x = source.x
        end_x = target.right
        control_gap = [ (start_x - end_x) * 0.45, 24 ].max
        "M #{coordinate(start_x)} #{coordinate(source_y)} " \
          "C #{coordinate(start_x - control_gap)} #{coordinate(source_y + lane)} " \
          "#{coordinate(end_x + control_gap)} #{coordinate(target_y + lane)} " \
          "#{coordinate(end_x)} #{coordinate(target_y)}"
      end
    end

    def set_dimensions
      max_depth = @nodes.map(&:depth).max || 0
      @width = [ MIN_WIDTH, (2 * GUTTER) + CARD_WIDTH + (max_depth * (CARD_WIDTH + COLUMN_GAP)) +
        (ROUTE_MARGIN + (@routes.length * ROUTE_LANE_GAP)) ].max
      @height = [ MIN_HEIGHT, @tree_bottom + ROUTE_MARGIN + (@routes.length * ROUTE_LANE_GAP) ].max
    end

    def coordinate(value)
      value.round(2).to_s
    end
end
