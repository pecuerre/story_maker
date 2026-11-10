# The interaction network of one Universe: how often each pair of Characters
# shares the page, across every live Scene of every live Story.
#
# The result is derived on every read and stores nothing. There are no counter
# columns and no background job, for the same reason the Appearance grid has no
# stored result: a Scene, Element, presence link, or Character is soft-deleted
# by six different write paths, and a counter would have to be repaired on every
# one of them plus every restore. The rows the network reads are the same live
# rows the rest of the application reads, so a deletion disappears from the next
# request by construction.
#
# **What counts.** A pair's score is
#
#   shared scenes × 1 + shared Dialogue Elements × 2 + exchanges × 1
#
# - a *shared scene* is a Scene where both are participants, using the union
#   `SceneParticipants` owns (an explicit `SceneCharacter` link or a Dialogue
#   speaker, never their sum);
# - a *shared Dialogue Element* is one Dialogue block where both speak;
# - an *exchange* is two adjacent turns in one Dialogue Element by different
#   speakers, so a back-and-forth is worth more than two monologues.
#
# A Relation is a stated link rather than a counted event, and a prose mention
# is a suggestion rather than an appearance (`docs/features/mentions.md`), so
# neither is an interaction source here.
#
# By default only Characters with at least one positive pair become nodes: a
# Character with no recorded interaction has no line to draw. A reader can ask
# for every live Character instead, which adds the unconnected ones as isolated
# nodes; that choice is the caller's and is carried in the page's URL.
#
# **A Relation** is a stated link between two Characters, so it is a third layer
# rather than interaction evidence. When the relation layer is on (the default),
# every live Relation between two nodes becomes a `RelationLink`, which the
# diagram draws as a dashed line in the color of the Relation's tag. A Relation
# still adds no score and never turns a mention into an appearance.
#
# **Faction membership** is the fallback layer. When it is on (the default),
# every pair of Characters in the same live Faction is returned as a
# `FactionLink`, which the diagram draws as a dotted line. A pair that already has
# an interaction edge or a Relation is not returned here: the stronger line wins,
# so a faction line is only drawn when neither of the other two applies. It never
# changes a pair's score or reorders the interaction edges. It is bounded
# separately by `MAX_FACTION_LINKS`.
#
# The graph is bounded: at most `MAX_NODES` Characters, `MAX_EDGES` interaction
# pairs, `MAX_RELATION_LINKS` Relation pairs, and `MAX_FACTION_LINKS` faction
# pairs are kept. A Universe can be much larger than a diagram that is readable,
# and the page states when it is showing a subset.
class CharacterNetwork
  MAX_NODES = 120
  MAX_EDGES = 240
  MAX_RELATION_LINKS = 160
  MAX_FACTION_LINKS = 160
  DIALOGUE_ELEMENT_POINTS = 2

  # One unordered pair's evidence, accumulated while the sources are read.
  PairStats = Struct.new(:scene_ids, :dialogue_element_ids, :exchanges, keyword_init: true) do
    def weight
      scene_ids.size + (DIALOGUE_ELEMENT_POINTS * dialogue_element_ids.size) + exchanges
    end
  end

  Edge = Data.define(:character_a, :character_b, :shared_scenes, :shared_dialogue_elements, :exchanges, :weight, :relation_tag) do
    def characters
      [ character_a, character_b ]
    end
  end

  Node = Data.define(:character, :interaction_total, :degree)

  # A same-faction pair. `factions` keeps every Faction that pair belongs to, so
  # two Characters in two factions still get one line rather than two.
  FactionLink = Data.define(:character_a, :character_b, :factions)

  # A stated link. `relation` is the first live Relation for the pair by id and
  # `relation_tag` is the first tag on any Relation for that pair, so the line has
  # one stable color even when a pair has several Relations.
  RelationLink = Data.define(:character_a, :character_b, :relation, :relation_tag)

  attr_reader :universe, :scenes, :nodes, :edges, :relation_links, :total_edge_count,
    :characters, :unconnected_characters, :connected_count, :faction_links

  def initialize(universe, include_unconnected: false, include_faction_links: true,
    include_relation_links: true)
    @universe = universe
    @include_unconnected = include_unconnected
    @include_faction_links = include_faction_links
    @include_relation_links = include_relation_links
    @faction_links_truncated = false
    @relation_links_truncated = false
    @scenes = Scene.where(story_id: universe.stories.select(:id)).reorder(:id).to_a
    @pairs = Hash.new do |hash, key|
      hash[key] = PairStats.new(scene_ids: Set.new, dialogue_element_ids: Set.new, exchanges: 0)
    end

    accumulate_scene_pairs
    accumulate_dialogue_pairs
    load_characters
    load_relations
    build_graph
  end

  def include_unconnected?
    @include_unconnected
  end

  def include_faction_links?
    @include_faction_links
  end

  def include_relation_links?
    @include_relation_links
  end

  def faction_links_truncated?
    @faction_links_truncated
  end

  def relation_links_truncated?
    @relation_links_truncated
  end

  def character_total
    characters.size
  end

  # With the unconnected layer on, every live Character is a node, so a Universe
  # with no interaction edge still draws its cast and any Relation or faction
  # links. The page is empty only when there is no node to draw at all.
  def empty?
    nodes.empty?
  end

  # True when the diagram is not showing every Character it would like to:
  # either the connected set or the whole Universe exceeded `MAX_NODES`.
  def nodes_truncated?
    nodes.size < (@include_unconnected ? character_total : connected_count)
  end

  # True when the Universe has more positive pairs than the diagram and the table
  # below it show. The count is the full derived total, not the returned subset.
  def truncated?
    edges.size < total_edge_count
  end

  private

    def accumulate_scene_pairs
      SceneParticipants.character_ids_by_scene(scenes).each do |scene_id, character_ids|
        ids = character_ids.uniq.sort
        ids.combination(2) do |first, second|
          @pairs[[ first, second ]].scene_ids << scene_id
        end
      end
    end

    # Dialogue needs the element and the turn order, which the presence union does
    # not expose. The union above is still the authority for who participates in a
    # Scene; this pass only adds the two signals that are specific to speaking.
    def accumulate_dialogue_pairs
      return if scenes.empty?

      element_ids = SceneElement.where(scene_id: scenes.map(&:id), kind: SceneElement::DIALOGUE).pluck(:id)
      return if element_ids.empty?

      turns = SceneDialogueTurn.joins(:speaker, :scene_element)
        .where(scene_elements: { id: element_ids })
        .order(:scene_element_id, :position, :id)
        .pluck(:scene_element_id, :speaker_id)

      turns.group_by(&:first).each do |element_id, element_turns|
        speakers = element_turns.map(&:last).uniq.sort
        speakers.combination(2) do |first, second|
          @pairs[[ first, second ]].dialogue_element_ids << element_id
        end

        element_turns.each_cons(2) do |(_, first), (_, second)|
          next if first == second

          @pairs[[ first, second ].sort].exchanges += 1
        end
      end
    end

    # A presence link or a turn can outlive a hard-deleted Character only through
    # data that bypassed the model, but the read must still not draw a node for a
    # record this Universe cannot open. Loading every live Character once also
    # gives the name sort, the total the summary states, and the isolated nodes
    # the optional toggle adds.
    def load_characters
      @characters = universe.characters.reorder(:name, :id).to_a
      @characters_by_id = @characters.index_by(&:id)
      @pairs.select! do |(first, second), _stats|
        @characters_by_id.key?(first) && @characters_by_id.key?(second)
      end
      @connected_ids = @pairs.keys.flatten.uniq.to_set
      @connected_count = @connected_ids.size
      @unconnected_characters = @characters.reject { |character| @connected_ids.include?(character.id) }
    end

    # A Relation is a stated link, not interaction evidence, so every live
    # Relation between two live Characters is kept here for both the dashed layer
    # and the table's tag badge. The graph is undirected: a Relation in either
    # direction belongs to the same sorted pair. Within one Relation the first tag
    # is chosen by `(position, id)`, the same order the taxonomy uses, because a
    # HABTM has no order of its own.
    #
    # For a pair with several Relations, the first Relation by id supplies the
    # link's identity and the first tagged Relation supplies its color. That keeps
    # an untagged Relation from hiding a later tagged one.
    def load_relations
      @relation_pairs = Set.new
      @relations_by_pair = {}
      @relation_tags_by_pair = {}

      Relation.where(universe_id: universe.id)
        .includes(:relation_tags)
        .order(:id)
        .each do |relation|
          first = relation.character1_id
          second = relation.character2_id
          next if first == second
          next unless @characters_by_id.key?(first) && @characters_by_id.key?(second)

          key = [ first, second ].sort
          @relation_pairs << key
          @relations_by_pair[key] ||= relation
          tag = relation.relation_tags.min_by { |candidate| [ candidate.position, candidate.id ] }
          @relation_tags_by_pair[key] ||= tag if tag
        end
    end

    def build_graph
      @total_edge_count = @pairs.size
      candidates = @pairs
        .sort_by { |(first, second), stats| [ -stats.weight, name_key(first), name_key(second), first, second ] }
        .first(MAX_EDGES)
        .map { |(first, second), stats| edge_for(first, second, stats) }

      totals = Hash.new(0)
      degrees = Hash.new(0)
      candidates.each do |edge|
        [ edge.character_a.id, edge.character_b.id ].each do |id|
          totals[id] += edge.weight
          degrees[id] += 1
        end
      end

      kept_ids = totals
        .sort_by { |id, total| [ -total, name_key(id), id ] }
        .first(MAX_NODES)
        .map(&:first)
        .to_set

      @edges = candidates.select do |edge|
        kept_ids.include?(edge.character_a.id) && kept_ids.include?(edge.character_b.id)
      end
      @edges = @edges.map do |edge|
        key = [ edge.character_a.id, edge.character_b.id ].sort
        edge.with(relation_tag: @relation_tags_by_pair[key])
      end

      totals.clear
      degrees.clear
      @edges.each do |edge|
        [ edge.character_a.id, edge.character_b.id ].each do |id|
          totals[id] += edge.weight
          degrees[id] += 1
        end
      end

      connected_nodes = kept_ids.filter_map do |id|
        character = @characters_by_id[id]
        next if character.nil? || totals[id].zero?

        Node.new(
          character: character,
          interaction_total: totals[id],
          degree: degrees[id]
        )
      end.sort_by { |node| [ -node.interaction_total, name_key(node.character.id), node.character.id ] }

      @nodes = connected_nodes + optional_unconnected_nodes(connected_nodes.size)
      @relation_links = @include_relation_links ? build_relation_links : []
      @faction_links = @include_faction_links ? build_faction_links : []
    end

    # Every live Relation between two nodes becomes one dashed link, deduplicated
    # by undirected pair. The cap is applied after the tag scan, so a pair already
    # kept still receives the first tagged Relation even when later pairs are
    # dropped. Only Characters that already became nodes are paired, matching the
    # faction layer's rule.
    def build_relation_links
      node_ids = @nodes.map { |node| node.character.id }.to_set
      return [] if node_ids.empty?

      links = {}
      @relation_pairs.each do |key|
        next unless node_ids.include?(key.first) && node_ids.include?(key.last)

        if links.size >= MAX_RELATION_LINKS
          @relation_links_truncated = true
          next
        end

        links[key] = RelationLink.new(
          character_a: @characters_by_id[key.first],
          character_b: @characters_by_id[key.last],
          relation: @relations_by_pair.fetch(key),
          relation_tag: @relation_tags_by_pair[key]
        )
      end

      links.values.sort_by do |link|
        [ name_key(link.character_a.id), name_key(link.character_b.id), link.character_a.id, link.character_b.id ]
      end
    end

    # Every pair in a faction is a candidate link, deduplicated across factions.
    # A pair that already has an interaction edge or a Relation is skipped: the
    # stronger line wins, so the dotted layer is only the fallback for a pair with
    # neither. Only Characters that already became nodes are paired, so turning
    # the unconnected toggle on is what includes a faction member with no recorded
    # interaction. Factions and members are ordered, so the cap and the layout are
    # stable.
    def build_faction_links
      node_ids = @nodes.map { |node| node.character.id }.to_set
      return [] if node_ids.empty?

      links = {}
      Faction.where(universe_id: universe.id).includes(:characters).order(:name, :id).each do |faction|
        member_ids = faction.characters.map(&:id).select { |id| node_ids.include?(id) }.sort
        next if member_ids.size < 2

        member_ids.combination(2) do |first, second|
          key = [ first, second ]
          next if @pairs.key?(key) || @relation_pairs.include?(key)

          if links.key?(key)
            links[key] << faction
          elsif links.size >= MAX_FACTION_LINKS
            @faction_links_truncated = true
            break
          else
            links[key] = [ faction ]
          end
        end
        break if @faction_links_truncated
      end

      links.map do |(first, second), factions|
        FactionLink.new(
          character_a: @characters_by_id[first],
          character_b: @characters_by_id[second],
          factions: factions
        )
      end.sort_by do |link|
        [ name_key(link.character_a.id), name_key(link.character_b.id), link.character_a.id, link.character_b.id ]
      end
    end

    # Isolated nodes share the same `MAX_NODES` budget as the connected graph, so
    # a large Universe cannot make the layout unbounded. The toggle keeps naming
    # the full count even when only part of it fits.
    def optional_unconnected_nodes(connected_count)
      return [] unless @include_unconnected

      budget = [ MAX_NODES - connected_count, 0 ].max
      @unconnected_characters.first(budget).map do |character|
        Node.new(character: character, interaction_total: 0, degree: 0)
      end
    end

    def edge_for(first_id, second_id, stats)
      Edge.new(
        character_a: @characters_by_id[first_id],
        character_b: @characters_by_id[second_id],
        shared_scenes: stats.scene_ids.size,
        shared_dialogue_elements: stats.dialogue_element_ids.size,
        exchanges: stats.exchanges,
        weight: stats.weight,
        relation_tag: nil
      )
    end

    def name_key(character_id)
      @characters_by_id[character_id]&.name.to_s.downcase
    end
end
