# Renumbers every ordered sequence in the database, or in one universe — and reports
# the same walk without writing anything.
#
# `PositionedResourceOrder` maintains a sequence for an application mutation and
# `OrderedSequence` repairs one for a write that reached a positioned model directly.
# **Neither can see a write that skipped the model entirely**: raw SQL from a console,
# `update_column`, `delete_all`, or a `create!` that names its own `position`. Nothing
# fires for a statement that does not run Active Record, so the gap such a write leaves
# stays open until something walks the sequence and renumbers it. That something is this.
#
# **Two verbs, one walk.** `#call` repairs; `#check` reports the same moves and writes
# nothing. They share every step of the derivation, so the check cannot drift onto a
# different set than the repair would fix — and the check is what closes the half a
# repair cannot: the command is a step somebody has to remember, and `#check` is how
# somebody finds out they forgot.
#
# It is the explicit import/console workflow finding 22 in
# [`docs/known_quirks.md`](../docs/known_quirks.md) says the raw paths would need, and
# the shape is deliberately the one already used for the other derived-data repair in
# this project — `Search::Reindexer` and its `search:reindex` /
# `search:reindex_universe` pair. It repairs; it does not rebuild, and it does not
# refuse an environment. See ADR 0009 for why the service remains the only writer that
# locks a scope owner, which this deliberately does not pretend to be.
#
# **Which records belong to one sequence is asked of the model, not decided here.**
# Every model declares it — `OrderedSequence#ordered_sequence_group_columns`, which
# `Hierarchical` narrows to `[scope, parent_id]` — so the group a record repairs itself
# within and the group this walks are the same definition read twice, rather than a
# second implementation in a service that could drift from the concern.
#
# **Every move is reported.** A person running this after an import needs to know what
# changed, and the ordering of a story is the author's work rather than derived data
# like a search index: silently renumbering a sequence nobody had broken would be worse
# than doing nothing. Each move names the record, the sequence it was in, and the two
# positions, so a surprising line in the output can be undone by hand.
class SequenceNormalizer
  # One record that was not where its position said it should be. `from` is the stored
  # position, `to` the index it now holds — the two are equal for a record that was
  # already right, and those are not reported at all.
  Move = Data.define(:model, :group, :record, :from, :to) do
    def to_s
      "#{model.name} #{record_label} in #{group}: position #{from} -> #{to}"
    end

    private
      # An Event is titled rather than named, so a name-shaped label would print an
      # empty string for it. The id is always there, which is what makes the line
      # useful even when the model names its record some other way.
      def record_label
        label = record.try(:name).presence || record.try(:title).presence
        label ? "#{label.inspect} (##{record.id})" : "##{record.id}"
      end
  end

  Summary = Data.define(:groups, :records, :moves, :applied) do
    def changed?
      moves.any?
    end

    # **The sentence says which of the two things happened.** One summary type serves
    # both entries, and "moved 3 record(s)" printed by a command that changed nothing
    # is the one way this output could mislead a person reading it.
    def to_s
      return applied ? "every sequence is already contiguous" : "every sequence is contiguous" unless changed?

      if applied
        "moved #{moves.size} record(s) across #{groups} sequence(s) holding #{records} record(s)"
      else
        "#{moves.size} record(s) across #{groups} sequence(s) holding #{records} record(s) are not contiguous"
      end
    end
  end

  def initialize(output: nil)
    @output = output
  end

  # **Eager loading first, or the list is whatever this process happened to touch.**
  # `ApplicationRecord.descendants` holds only loaded classes, so in a console or a task
  # — where nothing has referenced a model yet — a model that has a `position` column
  # would simply be missing from the run, and the command would report success over an
  # incomplete set. An abstract class is skipped because it has no table to read, which
  # is how `TaggedRecordsByTag` ends up in this list at all.
  #
  # The `position` column is the same test `DraftApplier` uses to decide whether a
  # model's sequence is the service's to maintain, and it is held against the routed
  # controllers there, so a new positioned model cannot escape it by being added to the
  # database alone.
  def self.positioned_models
    Rails.application.eager_load!

    ApplicationRecord.descendants
      .reject(&:abstract_class?)
      .select { |model| model.column_names.include?("position") }
      .sort_by(&:name)
  end

  # Every sequence in the database, repaired.
  def call
    normalize(nil)
  end

  # Every sequence belonging to one universe, which is the scope an import or a slug
  # rename actually needs: the other universes' sequences are untouched, and a mistake
  # in one cannot renumber another.
  def call_for_universe(universe)
    normalize(universe)
  end

  # The same walk, **writing nothing**. This is what closes the half of finding 22 a
  # repair cannot: `positions:normalize` is a step somebody has to remember, and
  # nothing noticed when it was forgotten. A check that reports the same thing without
  # touching a row turns a missed step from silent into visible, which is the whole
  # difference between "the command exists" and "somebody finds out".
  def check
    scan(nil)
  end

  # One universe's sequences, without writing.
  def check_for_universe(universe)
    scan(universe)
  end

  private
    attr_reader :output

    def normalize(universe)
      scan(universe, apply: true)
    end

    # One walk, two outcomes. The grouping, the ordering, and the set of records that
    # are wrong are the same questions either way, and the only thing `apply` decides
    # is whether the answer is written down — which is why the check cannot drift from
    # the repair by reporting on a different set than it would fix.
    def scan(universe, apply: false)
      groups = 0
      records = 0
      moves = []

      each_positioned_model do |model|
        model_moves, model_groups, model_records =
          if apply
            # One transaction per model rather than one for the run: a whole-database
            # repair on SQLite holds a write lock for as long as it takes, and a failure
            # half way through should leave the models it already finished consistent and
            # the rest exactly as they were, rather than rolling back work that was fine.
            ApplicationRecord.transaction { normalize_model(model, universe) }
          else
            inspect_model(model, universe, prefix: "would move ")
          end

        moves.concat(model_moves)
        groups += model_groups
        records += model_records
      end

      Summary.new(groups: groups, records: records, moves: moves, applied: apply)
    end

    def normalize_model(model, universe)
      moves, groups, records = inspect_model(model, universe, prefix: "")
      moves.each { |move| move.record.update_column(:position, move.to) }

      [ moves, groups, records ]
    end

    # Every group this model's records form, and every record in one of them that is
    # not where `(position, id)` says it should be. Nothing is written here, which is
    # what makes this the whole of the check — and what lets the repair reuse it rather
    # than keep a second copy of the same walk to drift.
    #
    # `prefix` is how a line says whether it describes a write that happened or one that
    # would. The same word for both is the difference between a report a person can act
    # on and one they have to re-read.
    def inspect_model(model, universe, prefix:)
      records = relation_for(model, universe).reorder(:position, :id).to_a
      return [ [], 0, 0 ] if records.empty?

      moves = []
      groups = 0

      records.group_by { |record| group_key(record, model) }.each_value do |group|
        groups += 1

        group.each_with_index do |record, index|
          next if record.position == index

          moves << Move.new(model: model, group: describe(group.first, model),
            record: record, from: record.position, to: index)
        end
      end

      moves.each { |move| report("#{prefix}#{move}") }
      [ moves, groups, records.size ]
    end

    # The values that make two records members of the same sequence, in the order the
    # model declares its group columns.
    def group_key(record, model)
      model.ordered_sequence_group_columns.map { |column| record.public_send(column) }
    end

    # The same values, named for a person reading the output: a `parent_id` of nil is
    # a root, and an id on its own is not a story or a scene a reader can name.
    def describe(record, model)
      model.ordered_sequence_group_columns.map do |column|
        case column
        when :parent_id then record.parent_id.nil? ? "top level" : "under ##{record.parent_id}"
        when :universe_id then Universe.find_by(id: record.universe_id)&.name || "universe ##{record.universe_id}"
        when :story_id then Story.find_by(id: record.story_id)&.name || "story ##{record.story_id}"
        when :scene_id then Scene.find_by(id: record.scene_id)&.name || "scene ##{record.scene_id}"
        when :scene_element_id
          element = SceneElement.find_by(id: record.scene_element_id)
          element ? "Element #{element.name.inspect}" : "scene element ##{record.scene_element_id}"
        else "#{column}=#{record.public_send(column)}"
        end
      end.join(" / ")
    end

    # The model's own records, restricted to one universe when asked. Which column
    # reaches a universe is the group's own scope column, so this is the same fact the
    # grouping uses rather than a fourth derivation of "what belongs to this universe".
    #
    # An unrecognised scope raises rather than falling back to the whole table: a
    # model scoped some other way would otherwise be normalized in every universe
    # while the caller believed it had been restricted to one.
    def relation_for(model, universe)
      return model.all if universe.nil?

      case model.ordered_sequence_group_columns.first
      when :universe_id then model.where(universe_id: universe.id)
      when :story_id then model.where(story_id: universe.stories.select(:id))
      when :scene_id then model.where(scene_id: universe.scenes.select(:id))
      when :scene_element_id
        model.joins(scene_element: { scene: :story }).where(stories: { universe_id: universe.id })
      else
        raise ArgumentError,
          "#{model.name} scopes its sequences by #{model.ordered_sequence_group_columns.first.inspect}, " \
          "which is not a scope this command can restrict to a universe."
      end
    end

    # A model with a `position` column and no group declaration would answer its own
    # repair with a nonsense column, so the walk is driven by the same list every other
    # caller of this concern is held against.
    def each_positioned_model(&block)
      self.class.positioned_models.each(&block)
    end

    def report(line)
      output&.puts(line)
    end
end
