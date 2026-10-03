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
#
# An edge is refused when it would close a cycle, which is the only thing that keeps a
# declaration the author wrote from contradicting the dates. `dates_speak_first?`
# establishes when that refusal is *possible* at all, which is what keeps the build from
# walking the graph once per candidate edge: see that method for the argument.
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
      # Resolved once. `UnionFind#find` is idempotent once every union is done, and
      # the three passes below ask it for both members of every pair — which on a long
      # timeline is half a million calls, more than everything else the build does.
      roots = @events.to_h { |event| [ event.id, union.find(event.id) ] }
      groups = Hash.new { |hash, key| hash[key] = [] }
      @events.each { |event| groups[roots[event.id]] << event }

      # Sets rather than Arrays: `include?` runs once per candidate edge and again for
      # the `ordered` test below, and a timeline of disjoint events produces one edge
      # per pair. An Array would make those two tests quadratic in a graph that is
      # already quadratic, which is what made this build superlinear.
      adjacency = Hash.new { |hash, key| hash[key] = Set.new }
      reverse_adjacency = Hash.new { |hash, key| hash[key] = Set.new }

      dates_speak_first = dates_speak_first?(groups)

      # `walk` is whether this candidate needs the reachability test. It is false for
      # the date passes on a timeline whose dates cannot contradict each other, and
      # always true for the explicit relations, which are the one place a contradiction
      # actually arrives from.
      add_edge = lambda do |from_root, to_root, walk: true|
        next if from_root.nil? || to_root.nil? || from_root == to_root
        next if adjacency[from_root].include?(to_root)
        next if walk && reachable?(adjacency, to_root, from_root)

        adjacency[from_root] << to_root
        reverse_adjacency[to_root] << from_root
      end

      ordered = lambda do |root_a, root_b|
        adjacency[root_a].include?(root_b) || adjacency[root_b].include?(root_a)
      end

      # Each pass below only ever looked at the pairs it could decide on, so it is
      # handed just those rows. Filtering keeps the pairs, and the order they arrive
      # in, exactly as iterating all of them and skipping the rest did.
      dated = @events.select { |event| event.start_datetime && event.end_datetime }
      started = @events.select(&:start_datetime)
      ended = @events.select(&:end_datetime)

      dated.combination(2).each do |a, b|
        root_a, root_b = roots[a.id], roots[b.id]
        next if root_a == root_b

        if a.end_datetime <= b.start_datetime
          add_edge.call(root_a, root_b, walk: !dates_speak_first || same_instant?(a, b))
        elsif b.end_datetime <= a.start_datetime
          add_edge.call(root_b, root_a, walk: !dates_speak_first || same_instant?(a, b))
        end
      end

      started.combination(2).each do |a, b|
        root_a, root_b = roots[a.id], roots[b.id]
        next if root_a == root_b || ordered.call(root_a, root_b)

        if a.start_datetime < b.start_datetime
          add_edge.call(root_a, root_b, walk: !dates_speak_first)
        elsif b.start_datetime < a.start_datetime
          add_edge.call(root_b, root_a, walk: !dates_speak_first)
        end
      end

      ended.combination(2).each do |a, b|
        root_a, root_b = roots[a.id], roots[b.id]
        next if root_a == root_b || ordered.call(root_a, root_b)

        if a.end_datetime < b.end_datetime
          add_edge.call(root_a, root_b, walk: !dates_speak_first)
        elsif b.end_datetime < a.end_datetime
          add_edge.call(root_b, root_a, walk: !dates_speak_first)
        end
      end

      @events.each do |event|
        # `before_event` happens no earlier than `event`; `after_event` happens no later than `event`.
        if event.before_event_id && @by_id[event.before_event_id]
          add_edge.call(roots[event.id], roots[event.before_event_id])
        end

        if event.after_event_id && @by_id[event.after_event_id]
          add_edge.call(roots[event.after_event_id], roots[event.id])
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

    # Whether an edge from one of the three date passes can close a cycle, which is
    # the only reason the reachability walk exists.
    #
    # It cannot, when every group is a single event and every declared range is
    # well-formed (no validation refuses `end` before `start` yet, so such a row is
    # legal data). Both conditions are needed, and together they make the walk dead
    # code:
    #
    # * A group of one event means an edge is justified by *that* event on each side,
    #   so along any path `v -> ... -> u` the declared starts are non-decreasing (pass 1
    #   needs `end_x <= start_y` plus a well-formed range; pass 2 states it outright).
    #   A pass-2 edge wants `start_a < start_b`, and a pass-1 edge wants
    #   `end_a <= start_b`, so with non-decreasing starts along the path either one
    #   contradicts the path unless every value involved is equal — which leaves only
    #   zero-length events at a single instant, checked separately as `same_instant?`.
    # * A pass-3 edge wants `end_a < end_b`. Ends are non-decreasing along a path for
    #   the same reason (`end_x <= start_y <= end_y`), so that one is a contradiction
    #   outright.
    #
    # What is left refusing an edge is the author's own `before_event`/`after_event`,
    # and those are one per event rather than one per pair.
    #
    # A timeline that declares simultaneity, or that carries a reversed interval, gets
    # the walk on every candidate edge exactly as before: a group of several events can
    # justify one edge through its earliest event and another through its latest, and a
    # reversed interval breaks the non-decreasing argument above. Both are rare, and
    # neither may change an answer.
    def dates_speak_first?(groups)
      groups.size == @events.size && @events.all? { |event| well_formed_range?(event) }
    end

    def well_formed_range?(event)
      event.start_datetime.nil? || event.end_datetime.nil? ||
        event.end_datetime >= event.start_datetime
    end

    # The one date-pass candidate that can still close a cycle: two zero-length events
    # at the same instant, where "a ends before b starts" holds and so does its
    # reverse, and a path between them can exist among further such events.
    def same_instant?(a, b)
      a.start_datetime == a.end_datetime && b.start_datetime == b.end_datetime &&
        a.start_datetime == b.start_datetime
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
      stack.concat(adjacency[node].to_a)
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
