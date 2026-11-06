# Presentation data for the Character interaction network: node positions,
# radii, labels, and edge weights, derived for each render and never written
# back to a record.
#
# The layout is a deterministic Fruchterman-Reingold simulation. The seed is
# fixed and the input order is the network's own stable order, so the same
# records at the same revision always produce the same picture — a test can hold
# coordinates, and a reader who reloads does not see the graph jump. Stronger
# pairs are pulled a little harder, so tightly interacting Characters sit
# together, while the universal repulsion keeps unrelated groups apart.
class CharacterNetworkLayout
  MIN_WIDTH = 900
  MAX_WIDTH = 1400
  MIN_HEIGHT = 420
  ASPECT = 0.7
  PADDING = 56
  ITERATIONS = 180
  INITIAL_TEMPERATURE = 0.16
  COOLING = 0.975
  GRAVITY = 0.05
  SEED = 20_261_106

  MIN_RADIUS = 7.0
  MAX_RADIUS = 23.0
  MAX_LABEL_LENGTH = 22

  MIN_STROKE = 1.2
  MAX_STROKE = 4.5

  # A faction link is not interaction, so it has no score. It still pulls its two
  # nodes together like a small interaction, which is what places faction members
  # as a group instead of scattering the characters with no Scene connection.
  FACTION_LINK_PULL = 2.0

  Node = Data.define(:character, :x, :y, :radius, :label, :interaction_total, :degree)
  Edge = Data.define(:source, :target, :weight, :stroke_width, :relation_tag)
  FactionLink = Data.define(:source, :target, :factions)

  attr_reader :nodes, :edges, :faction_links, :width, :height

  def initialize(network)
    @network = network
    @width = width_for(network.nodes.size)
    @height = [ (@width * ASPECT).round, MIN_HEIGHT ].max
    positions = simulate
    @nodes = build_nodes(positions)
    @edges = build_edges
    @faction_links = build_faction_links
  end

  private

    def width_for(count)
      (Math.sqrt(count) * 200).round.clamp(MIN_WIDTH, MAX_WIDTH)
    end

    # Returns `{ character_id => [x, y] }` for every node, already scaled into
    # the drawing area. Interaction edges and faction links are both springs, so
    # the layout groups faction members even when they share no Scene. Coordinates
    # stay inside the padding, so a label drawn under a node still fits inside the
    # viewBox.
    def simulate
      nodes = @network.nodes
      count = nodes.size
      return {} if count.zero?

      random = Random.new(SEED)
      xs = Array.new(count) { 0.12 + (random.rand * 0.76) }
      ys = Array.new(count) { 0.12 + (random.rand * 0.76) }
      index_by_id = nodes.each_with_index.to_h { |node, index| [ node.character.id, index ] }
      springs = @network.edges.map do |edge|
        [ index_by_id.fetch(edge.character_a.id), index_by_id.fetch(edge.character_b.id), edge.weight ]
      end
      springs.concat(@network.faction_links.map do |link|
        [ index_by_id.fetch(link.character_a.id), index_by_id.fetch(link.character_b.id), FACTION_LINK_PULL ]
      end)

      ideal = Math.sqrt(1.0 / count)
      temperature = INITIAL_TEMPERATURE

      ITERATIONS.times do
        dx = Array.new(count, 0.0)
        dy = Array.new(count, 0.0)
        apply_repulsion(xs, ys, dx, dy, ideal)
        apply_attraction(xs, ys, dx, dy, springs, ideal)
        apply_gravity_and_cooling(xs, ys, dx, dy, temperature)
        temperature *= COOLING
      end

      normalize(xs, ys).each_with_index.to_h do |(x, y), index|
        [ nodes[index].character.id, [ x, y ] ]
      end
    end

    def apply_repulsion(xs, ys, dx, dy, ideal)
      xs.each_index do |first|
        ((first + 1)...xs.length).each do |second|
          delta_x = xs[first] - xs[second]
          delta_y = ys[first] - ys[second]
          distance_squared = (delta_x * delta_x) + (delta_y * delta_y)
          next if distance_squared < 1e-9

          distance = Math.sqrt(distance_squared)
          force = (ideal * ideal) / distance
          offset_x = (delta_x / distance) * force
          offset_y = (delta_y / distance) * force
          dx[first] += offset_x
          dy[first] += offset_y
          dx[second] -= offset_x
          dy[second] -= offset_y
        end
      end
    end

    def apply_attraction(xs, ys, dx, dy, springs, ideal)
      springs.each do |first, second, weight|
        delta_x = xs[first] - xs[second]
        delta_y = ys[first] - ys[second]
        distance = Math.sqrt((delta_x * delta_x) + (delta_y * delta_y))
        next if distance < 1e-6

        force = ((distance * distance) / ideal) * (0.8 + (0.4 * Math.log(1 + weight)))
        offset_x = (delta_x / distance) * force
        offset_y = (delta_y / distance) * force
        dx[first] -= offset_x
        dy[first] -= offset_y
        dx[second] += offset_x
        dy[second] += offset_y
      end
    end

    def apply_gravity_and_cooling(xs, ys, dx, dy, temperature)
      xs.each_index do |index|
        dx[index] += (0.5 - xs[index]) * GRAVITY
        dy[index] += (0.5 - ys[index]) * GRAVITY
        length = Math.sqrt((dx[index] * dx[index]) + (dy[index] * dy[index]))
        next if length < 1e-9

        step = [ length, temperature ].min / length
        xs[index] = (xs[index] + (dx[index] * step)).clamp(0.02, 0.98)
        ys[index] = (ys[index] + (dy[index] * step)).clamp(0.02, 0.98)
      end
    end

    def normalize(xs, ys)
      min_x, max_x = xs.minmax
      min_y, max_y = ys.minmax
      span_x = max_x - min_x
      span_y = max_y - min_y
      inner_width = width - (2 * PADDING)
      inner_height = height - (2 * PADDING)

      xs.each_index.map do |index|
        x = span_x < 1e-6 ? width / 2.0 : PADDING + (((xs[index] - min_x) / span_x) * inner_width)
        y = span_y < 1e-6 ? height / 2.0 : PADDING + (((ys[index] - min_y) / span_y) * inner_height)
        [ x.round(2), y.round(2) ]
      end
    end

    def build_nodes(positions)
      max_total = @network.nodes.map(&:interaction_total).max.to_f
      @network.nodes.map do |node|
        x, y = positions.fetch(node.character.id)
        Node.new(
          character: node.character,
          x: x,
          y: y,
          radius: radius_for(node.interaction_total, max_total),
          label: truncate_label(node.character.name),
          interaction_total: node.interaction_total,
          degree: node.degree
        )
      end
    end

    def radius_for(total, max_total)
      return MIN_RADIUS if max_total.zero?

      (MIN_RADIUS + ((MAX_RADIUS - MIN_RADIUS) * Math.sqrt(total / max_total))).round(2)
    end

    def truncate_label(name)
      value = name.to_s
      return value if value.length <= MAX_LABEL_LENGTH

      "#{value[0, MAX_LABEL_LENGTH - 1]}…"
    end

    def build_faction_links
      nodes_by_id = nodes.index_by { |node| node.character.id }
      @network.faction_links.filter_map do |link|
        source = nodes_by_id[link.character_a.id]
        target = nodes_by_id[link.character_b.id]
        next unless source && target

        FactionLink.new(source: source, target: target, factions: link.factions)
      end
    end

    def build_edges
      nodes_by_id = nodes.index_by { |node| node.character.id }
      max_weight = @network.edges.map(&:weight).max.to_f
      @network.edges.filter_map do |edge|
        source = nodes_by_id[edge.character_a.id]
        target = nodes_by_id[edge.character_b.id]
        next unless source && target

        Edge.new(
          source: source,
          target: target,
          weight: edge.weight,
          stroke_width: stroke_width_for(edge.weight, max_weight),
          relation_tag: edge.relation_tag
        )
      end
    end

    def stroke_width_for(weight, max_weight)
      return MIN_STROKE if max_weight.zero?

      (MIN_STROKE + ((MAX_STROKE - MIN_STROKE) * (weight / max_weight))).round(2)
    end
end
