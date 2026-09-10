# Simple disjoint-set structure used to group events known to happen at the same time.
class UnionFind
  def initialize(ids)
    @parent = {}
    ids.each { |id| @parent[id] = id }
  end

  def find(id)
    return id unless @parent.key?(id)

    root = id
    root = @parent[root] while @parent[root] != root

    node = id
    while @parent[node] != root
      @parent[node], node = root, @parent[node]
    end

    root
  end

  def union(a, b)
    return unless @parent.key?(a) && @parent.key?(b)

    root_a, root_b = find(a), find(b)
    return if root_a == root_b

    @parent[root_b] = root_a
  end
end
