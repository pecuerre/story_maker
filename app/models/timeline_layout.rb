# Computes a layered ordering of a universe's events for the Timeline view.
#
# Events are grouped together when they are marked as happening at the same time
# (via `simultaneous_event`), then a directed "happens no later than" graph is built
# between the remaining groups using, in order of confidence:
#   1. full start/end date ranges that don't overlap
#   2. start dates alone
#   3. end dates alone
#   4. explicit before_event / after_event relations
#
# The resulting DAG is then arranged into layers (rows) using longest-path layering,
# so that anything with no known predecessor sits on the top row, and everything else
# is placed at least one row below all of its known predecessors.
#
# `@layers` is the single source of truth for that ordering, and the arrows the view
# draws are derived from it rather than from the raw associations, so the two can
# never contradict each other.
class TimelineLayout
  attr_reader :layers, :edges

  def initialize(events)
    @events = events.to_a
    @by_id = @events.index_by(&:id)
    build
  end

  private

  def build
    union = build_union_find
    groups = Hash.new { |hash, key| hash[key] = [] }
    @events.each { |event| groups[union.find(event.id)] << event }

    adjacency = Hash.new { |hash, key| hash[key] = [] }
    reverse_adjacency = Hash.new { |hash, key| hash[key] = [] }

    add_edge = lambda do |from_root, to_root|
      next if from_root.nil? || to_root.nil? || from_root == to_root
      next if adjacency[from_root].include?(to_root)
      next if reachable?(adjacency, to_root, from_root)

      adjacency[from_root] << to_root
      reverse_adjacency[to_root] << from_root
    end

    ordered = lambda do |root_a, root_b|
      adjacency[root_a].include?(root_b) || adjacency[root_b].include?(root_a)
    end

    @events.combination(2).each do |a, b|
      root_a, root_b = union.find(a.id), union.find(b.id)
      next if root_a == root_b

      if a.start_datetime && a.end_datetime && b.start_datetime && b.end_datetime
        if a.end_datetime <= b.start_datetime
          add_edge.call(root_a, root_b)
        elsif b.end_datetime <= a.start_datetime
          add_edge.call(root_b, root_a)
        end
      end
    end

    @events.combination(2).each do |a, b|
      root_a, root_b = union.find(a.id), union.find(b.id)
      next if root_a == root_b || ordered.call(root_a, root_b)
      next unless a.start_datetime && b.start_datetime

      if a.start_datetime < b.start_datetime
        add_edge.call(root_a, root_b)
      elsif b.start_datetime < a.start_datetime
        add_edge.call(root_b, root_a)
      end
    end

    @events.combination(2).each do |a, b|
      root_a, root_b = union.find(a.id), union.find(b.id)
      next if root_a == root_b || ordered.call(root_a, root_b)
      next unless a.end_datetime && b.end_datetime

      if a.end_datetime < b.end_datetime
        add_edge.call(root_a, root_b)
      elsif b.end_datetime < a.end_datetime
        add_edge.call(root_b, root_a)
      end
    end

    @events.each do |event|
      # `before_event` happens no earlier than `event`; `after_event` happens no later than `event`.
      if event.before_event_id && @by_id[event.before_event_id]
        add_edge.call(union.find(event.id), union.find(event.before_event_id))
      end

      if event.after_event_id && @by_id[event.after_event_id]
        add_edge.call(union.find(event.after_event_id), union.find(event.id))
      end
    end

    levels = compute_levels(groups.keys, reverse_adjacency)

    max_level = levels.values.max || 0
    @layers = Array.new(max_level + 1) { [] }
    groups.each do |root, group_events|
      @layers[levels[root]].concat(group_events.sort_by(&:id))
    end
    @layers.each { |layer| layer.sort_by! { |event| event.id } }

    @edges = build_edges(union, levels)
  end

  # The arrows the view draws are read off the resolved layout, never off the raw
  # associations. A `before_event`/`after_event` the graph refused — because the
  # declared order contradicted a stronger signal, or because accepting it would
  # have closed a cycle — leaves no row ordering behind it, so drawing it would
  # put an arrow pointing the wrong way across rows that say the opposite. Only a
  # relation the layering actually kept is emitted, and only once: two events that
  # name each other, or one that names the other in both fields, describe a single
  # arrow.
  def build_edges(union, levels)
    edges = []
    seen = Set.new

    @events.each do |event|
      if (target = @by_id[event.before_event_id])
        push_edge(edges, seen, union, levels, from: event, to: target, kind: "sequence")
      end

      if (target = @by_id[event.after_event_id])
        push_edge(edges, seen, union, levels, from: target, to: event, kind: "sequence")
      end

      # Simultaneous events share a union-find group, so they are on one row by
      # construction and the connecting line can never contradict the layout.
      if (target = @by_id[event.simultaneous_event_id])
        push_edge(edges, seen, union, levels, from: event, to: target, kind: "simultaneous", same_row: true)
      end
    end

    edges
  end

  # `from` must sit strictly above `to` for a directed arrow to be honest. A
  # simultaneous edge is the one exception: it joins two events on the *same* row.
  def push_edge(edges, seen, union, levels, from:, to:, kind:, same_row: false)
    from_level = levels[union.find(from.id)]
    to_level = levels[union.find(to.id)]
    agrees = same_row ? from_level == to_level : from_level < to_level
    return unless agrees

    edge = { from: from.id, to: to.id, kind: kind }
    return unless seen.add?(edge)

    edges << edge
  end

  def build_union_find
    union = UnionFind.new(@events.map(&:id))
    @events.each do |event|
      union.union(event.id, event.simultaneous_event_id) if event.simultaneous_event_id && @by_id[event.simultaneous_event_id]
    end
    union
  end

  def reachable?(adjacency, from, to)
    return true if from == to

    visited = Set.new
    stack = [ from ]
    until stack.empty?
      node = stack.pop
      next if visited.include?(node)
      visited << node
      return true if node == to
      stack.concat(adjacency[node])
    end

    false
  end

  def compute_levels(group_ids, reverse_adjacency)
    levels = {}

    compute = lambda do |node|
      next levels[node] if levels.key?(node)

      predecessors = reverse_adjacency[node]
      levels[node] = predecessors.empty? ? 0 : predecessors.map { |p| compute.call(p) }.max + 1
    end

    group_ids.each { |group_id| compute.call(group_id) }
    levels
  end
end
