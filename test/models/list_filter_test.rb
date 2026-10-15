require "test_helper"

# The contract every list filter shares. `SceneFilter` is the one filter that
# existed before it, so the proof that this is a contract rather than a
# refactor is that it narrows a **different** model through the same shared
# narrowings: nothing here is a Scene, a story, or a Scene Tag.
#
# The messages this double discards with are the Scene filter's own keys, because
# a workspace's real filter has not shipped its keys yet and inventing them here
# would put locale debt in a test. What is under test is that a dropped value is
# **reported and translated**, not which sentence says so.
class ListFilterTest < ActiveSupport::TestCase
  # A deliberately small filter over a model `SceneFilter` never touches, built
  # only from the shared pieces. A slice that adds a workspace's real filter
  # writes this shape's `resolve`, `query_params`, and `apply`, and nothing else.
  class CharacterFilter < ListFilter
    PARAMS = %i[ q parent_id from ].freeze

    attr_reader :parent, :from_date

    def initialize(params, characters:)
      @characters = characters
      super(params)
    end

    def query_params
      query = {}
      query[:q] = text if text.present?
      query[:parent_id] = parent&.id.to_s if parent
      query[:from] = from_date.iso8601 if from_date
      query
    end

    def apply(relation)
      relation = narrowed_by_text(relation, table: "characters", columns: %w[ name description ])
      relation = relation.where(parent_id: parent.id) if parent
      relation = narrowed_by_day_range(relation, :created_at, from: from_date)
      relation.order(:name, :id)
    end

    private
      def resolve
        resolve_text
        @parent = resolve_in_list(@params[:parent_id], @characters,
          "scenes.filter.discarded.section", identifier: :id)
        @from_date = resolve_day(@params[:from],
          label_key: "scenes.filter.bound.start",
          discard_key: "scenes.filter.discarded.date")
      end
  end

  setup do
    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
    @character_three = characters(:character_three)
    # A parent relationship, because the value a filter resolves out of an
    # already-loaded list is a record the narrowed query then matches on.
    @character_three.update!(parent: @character_one)
    # Descriptions are what the text filter reads besides the name, and fixed
    # timestamps are what the day range reads, so neither depends on when the
    # fixtures were loaded.
    @character_one.update!(description: "The keeper of the gate", created_at: Time.utc(2026, 10, 2, 23, 59))
    @character_two.update!(description: "The sworn companion", created_at: Time.utc(2026, 1, 5))
    @character_three.update!(description: "The silent cartographer", created_at: Time.utc(2026, 6, 1))

    @candidates = [ @character_one, @character_two, @character_three ]
    @candidates_ids = apply_with(filter_for).map(&:id)
  end

  test "the free text of every list filter is the q key" do
    assert_equal :q, ListFilter::TEXT_PARAM
    assert_equal [ @character_three ], apply(q: "cartographer")
    assert_equal [ @character_one ], apply(q: "keeper")
    assert_equal [ @character_one ], apply(q: "KEEPER"), "a search box ignores case"
  end

  test "surrounding whitespace is not text to search for, and a blank box is not a filter" do
    assert_equal [ @character_one ], apply(q: "  Character one  ")
    assert_not filter_for(q: "   ").active?
    assert_equal @candidates_ids, apply(q: "   ").map(&:id)
  end

  test "a list of records is matched by its id, which is the part that travels in the URL" do
    assert_equal [ @character_three ], apply(parent_id: @character_one.id.to_s)
  end

  test "a value that is not in the already-loaded list is dropped and reported" do
    foreign = filter_for(parent_id: characters(:character_other_universe).id.to_s)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/was ignored because it is not a section of this story/, foreign.discarded.first)
    assert_equal @candidates_ids, apply_with(foreign).map(&:id), "a dropped value narrows nothing"
  end

  test "a dropped value is not carried into the canonical query" do
    assert_empty filter_for(parent_id: characters(:character_other_universe).id).query_params
    assert_equal({ parent_id: @character_one.id.to_s }, filter_for(parent_id: @character_one.id).query_params)
  end

  test "an active filter reports exactly the keys in effect" do
    filter = filter_for(q: "gate", from: "2026-01-01")

    assert filter.active?
    assert_equal({ q: "gate", from: "2026-01-01" }, filter.query_params)
  end

  test "an empty filter changes nothing and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_empty filter.discarded
    assert_empty filter.query_params
    assert_equal @candidates_ids, apply_with(filter).map(&:id)
  end

  test "an unreadable day is reported rather than guessed at, and the rest still applies" do
    broken = filter_for(from: "not-a-date", q: "gate")

    assert_equal [ @character_one ], apply_with(broken)
    assert_equal 1, broken.discarded.size
    assert_match(/could not be read/, broken.discarded.first)
    assert_equal({ q: "gate" }, broken.query_params)
  end

  test "a day range is inclusive of the whole bound day and excludes an earlier one" do
    assert_equal [ @character_one ], apply_with(filter_for(from: "2026-10-02")),
      "the bounds are days, so a record later the same day is still inside them"
    assert_equal [ @character_one, @character_three ], apply_with(filter_for(from: "2026-06-01"))
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @character_two.update!(name: "100% of the oath")

    assert_equal [ "100% of the oath" ], apply(q: "100%").map(&:name)
    assert_equal [ "100% of the oath" ], apply(q: "%").map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "a subclass that does not finish the contract fails loudly rather than filtering nothing" do
    unfinished = Class.new(ListFilter) do
      def self.name = "UnfinishedFilter"
    end

    assert_raises(NotImplementedError) { unfinished.params }
    assert_raises(NotImplementedError) { unfinished.new({}).query_params }
    assert_raises(NotImplementedError) { unfinished.new({}).apply(Character.all) }
  end

  private
    def filter_for(**params)
      CharacterFilter.new(params, characters: @candidates)
    end

    def apply(**params)
      apply_with(filter_for(**params))
    end

    def apply_with(filter)
      filter.apply(Character.where(universe: @character_one.universe)).to_a
    end
end
