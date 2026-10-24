require "test_helper"

# Authorization and the shared view helpers must resolve a record's Universe the
# same way, or a writer sees missing controls while a record-level check denies
# an allowed mutation. Both paths are covered here.
class UniverseScopeResolverTest < ActiveSupport::TestCase
  # Stand-ins for a model nested below everything the walk names, borrowing the
  # shape of the speaker join table: a `scene_element_id` and nothing the resolver
  # can walk from or filter by. The application has no model class for that join,
  # so these supply one.
  #
  # They are deliberately not `ApplicationRecord` subclasses. A test-defined
  # persisted model would appear in `ApplicationRecord.descendants` and fail
  # `ability_test.rb`'s inverted content registry, which exists to catch a model
  # nobody registered — not a test fixture that registered nothing on purpose.
  # `records_in` asks only what a class can answer about itself, so a plain class
  # answers the same questions faithfully.
  class NestedRecord
    COLUMNS = %w[id widget_id character_id].freeze

    attr_reader :widget_id

    def initialize(widget_id: nil)
      @widget_id = widget_id
    end

    def self.name = "NestedRecord"
    def self.table_name = "scene_element_speakers"
    def self.column_names = COLUMNS
  end

  # The same shape after taking the advice: it declares its scope and delegates to
  # the owner it holds. That clears the record-level walk and still does not make
  # the class filterable, which is the boundary the two halves of the fix sit on —
  # `universe_for` walks in Ruby and accepts a delegation, `records_in` filters in
  # SQL and cannot.
  class DeclaredNestedRecord < NestedRecord
    def self.name = "DeclaredNestedRecord"

    def initialize(owner:, widget_id: nil)
      super(widget_id: widget_id)
      @owner = owner
    end

    def universe = @owner&.universe
  end

  setup do
    @universe = universes(:universe_one)
  end

  test "resolves a direct universe owner" do
    assert_equal @universe, UniverseScopeResolver.universe_for(characters(:character_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(events(:event_one))
  end

  test "resolves a story-scoped record through its story" do
    assert_equal @universe, UniverseScopeResolver.universe_for(sections(:section_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(plots(:plot_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(section_tags(:section_tag_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_tags(:scene_tag_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scenes(:scene_one))
  end

  test "resolves a scene-owned record through its scene" do
    scene = scenes(:scene_one)
    component = Struct.new(:scene).new(scene)

    assert_equal @universe, UniverseScopeResolver.universe_for(component)
  end

  test "resolves the real scene-owned models through their scene" do
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_elements(:narration_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_elements(:dialogue_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_dialogue_turns(:turn_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_characters(:scene_character_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_characters(:scene_character_two))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_items(:scene_item_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_locations(:scene_location_one))
    # Unsaved records own nothing yet, so there is no universe to resolve.
    assert_nil UniverseScopeResolver.universe_for(SceneElement.new(name: "Unsaved"))
    assert_nil UniverseScopeResolver.universe_for(SceneDialogueTurn.new)
    assert_nil UniverseScopeResolver.universe_for(SceneCharacter.new)
    assert_nil UniverseScopeResolver.universe_for(SceneItem.new)
    assert_nil UniverseScopeResolver.universe_for(SceneLocation.new)
  end

  test "a deeper component resolves through its own universe delegation" do
    # A speaker link belongs to a Scene Element rather than directly to a Scene.
    # It therefore delegates through its owner instead of adding an entry here,
    # and the resolver picks that delegation up on its first step.
    element = Struct.new(:universe).new(@universe)
    speaker = Struct.new(:universe, :scene_element).new(element.universe, element)

    assert_equal @universe, UniverseScopeResolver.universe_for(speaker)
  end

  test "resolves a section-owned record through its section" do
    section_owned = Struct.new(:section).new(sections(:section_two))

    assert_equal @universe, UniverseScopeResolver.universe_for(section_owned)
  end

  test "returns nil when nothing in the chain owns a universe" do
    assert_nil UniverseScopeResolver.universe_for(nil)
    assert_nil UniverseScopeResolver.universe_for(Story.new(name: "Unsaved"))
    assert_nil UniverseScopeResolver.universe_for(Struct.new(:story).new(nil))
  end

  test "the ability and the view helper agree for a scene and a scene-owned record" do
    ability = Ability.new(users(:user_one))
    scene = scenes(:scene_one)
    scene_owned = Struct.new(:scene).new(scene)

    assert_equal UniverseScopeResolver.universe_for(scene),
      UniverseScopeResolver.universe_for(scene_owned)
    assert_equal UniverseScopeResolver.universe_for(scene_owned),
      ability.send(:universe_for, scene_owned)
    assert ability.can?(:write, scene)
  end

  # The same walk, asked of a class rather than of a record, because three callers
  # need it before there is a record to walk from: the remembering path choosing
  # the column a create stores, the applier choosing the collection to order, and a
  # draft's own page telling that plumbing from something it can print.

  test "names the owner association a model reaches its universe through" do
    assert_equal :story, UniverseScopeResolver.owner_association_for(Section)
    assert_equal :story, UniverseScopeResolver.owner_association_for(Plot)
    assert_equal :story, UniverseScopeResolver.owner_association_for(Scene)
    assert_equal :scene, UniverseScopeResolver.owner_association_for(SceneElement)
    assert_equal :scene_element, UniverseScopeResolver.owner_association_for(SceneDialogueTurn)
    assert_equal :scene, UniverseScopeResolver.owner_association_for(SceneCharacter)
    # A record with a `universe_id` of its own has no owner association to walk.
    assert_nil UniverseScopeResolver.owner_association_for(Character)
  end

  test "the answer agrees with the walk, for every model it is asked about" do
    [ Section, Plot, Scene, SceneElement, SceneDialogueTurn, SceneCharacter, Character ].each do |model|
      record = model.first
      next if record.nil?

      owner = UniverseScopeResolver.owner_association_for(model)
      walked = owner ? record.public_send(owner)&.universe : record.universe

      assert_equal UniverseScopeResolver.universe_for(record), walked,
        "#{model.name}: the column the derivation reads and the walk the resolver performs must reach the " \
        "same universe, or a remembered change would be placed in a scope the record is not in"
    end
  end

  test "records_in names a model the walk cannot place instead of querying a column that is not there" do
    # A join record whose foreign key names nothing the walk can follow has no
    # column to filter it by. Asked of the class, reaching the database with
    # `universe_id` produces a missing-column error that reads like an absent
    # migration rather than a model that never declared its scope.
    error = assert_raises(UniverseScopeResolver::UnresolvableModel) do
      UniverseScopeResolver.records_in(NestedRecord, @universe)
    end

    assert_match(/NestedRecord/, error.message)
    assert_match(/universe_id/, error.message)
    assert_match(/define #universe/, error.message)
  end

  test "declaring its own universe is what clears the record-level walk" do
    undeclared = NestedRecord.new(widget_id: scene_elements(:narration_one).id)
    declared = DeclaredNestedRecord.new(owner: scene_elements(:narration_one))

    assert_nil UniverseScopeResolver.universe_for(undeclared),
      "without the declaration the walk resolves to nothing, which is the whole footgun"
    assert_equal @universe, UniverseScopeResolver.universe_for(declared),
      "defining #universe to delegate through the owner must be enough to clear the walk"
  end

  test "a model that declared its universe is told it still needs a column" do
    # The delegation the resolver finds in Ruby is not something SQL can filter on,
    # so a class-level check about this model cannot be answered by the delegation
    # alone. Saying so is the point: the alternative is a missing-column error that
    # reads like an absent migration.
    error = assert_raises(UniverseScopeResolver::UnresolvableModel) do
      UniverseScopeResolver.records_in(DeclaredNestedRecord, @universe)
    end

    assert_match(/DeclaredNestedRecord/, error.message)
    assert_match(/content registry/, error.message)
  end

  test "every content model resolves a universe for every persisted row" do
    # A model the walk cannot place resolves nothing, which is not an error the
    # walk can raise: it loses both its authorization checks and its mutation
    # controls and nothing else complains. So the whole content registry is
    # checked here rather than the models that happen to have fixtures.
    #
    # Soft-deleted rows are included, because a row that an owner still points at
    # has to resolve whatever its owner's state, and a soft-deleted owner is still
    # an owner.
    Ability::CONTENT_CLASS_NAMES.each do |name|
      model = name.constantize
      rows = model.respond_to?(:with_deleted) ? model.with_deleted : model.all

      unresolved = rows.reject { |record| UniverseScopeResolver.universe_for(record) }

      assert_empty unresolved.map(&:id),
        "#{name} must resolve its universe for every row. A model nested below a story, scene, or section " \
        "has to define its own #universe, or the walk resolves to nothing and the record silently loses " \
        "both its authorization checks and its rendered controls."
    end
  end

  test "every content model can be filtered by universe without the walk failing" do
    # The class-level half of the same contract: `records_in` is what
    # `Ability#class_answer` asks when there is no record to walk from, so a model
    # it cannot place is a model whose class checks raise instead of answering.
    assert_nothing_raised do
      Ability::CONTENT_CLASS_NAMES.each do |name|
        UniverseScopeResolver.records_in(name.constantize, @universe)
      end
    end
  end

  test "records_in selects exactly the rows whose record resolves to that universe" do
    # A class-level authorization check asks this question before there is a
    # record to walk from, so the relation it filters on and the walk it mirrors
    # have to select the same rows. A model that disagreed here would answer a
    # class check about rows the record check would not have allowed.
    other_universe = Universe.create!(owner: users(:user_one), name: "Elsewhere", slug: "elsewhere")

    Ability::CONTENT_CLASS_NAMES.each do |name|
      model = name.constantize
      expected = model.all.select { |record| UniverseScopeResolver.universe_for(record) == @universe }
      actual = UniverseScopeResolver.records_in(model, @universe).to_a

      assert_equal expected.map(&:id).sort, actual.map(&:id).sort,
        "#{name}: records_in must select the rows that resolve to the universe, no more and no fewer"
      assert_empty UniverseScopeResolver.records_in(model, other_universe).to_a,
        "#{name}: a universe with nothing in it selects nothing"
    end
  end
end
