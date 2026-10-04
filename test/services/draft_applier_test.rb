require "test_helper"

# Writing one author's remembered changes into the universe.
#
# `test/controllers/drafts_controller_test.rb` walks the whole journey through the
# request path, and `test/controllers/draft_mutation_test.rb` covers all twenty
# controllers on the way in. What is only answerable here is the derivation the
# applier makes instead of keeping a list, because a list can only be held against
# another list — so these tests walk the routed controllers themselves and fail
# when the two answers stop agreeing.
class DraftApplierTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @character = characters(:character_one)
  end

  # The derivation, held against the controllers that declare their own ordering.

  test "every controller that maintains sibling positions is a model the applier orders" do
    controllers = positioned_controllers
    assert_equal 15, controllers.size,
      "the number of ordered controllers is what the derivation is checked against; a new one changes it"

    controllers.each do |controller|
      model = ordered_model(controller)
      assert DraftApplier.ordered?(model),
        "#{controller.name} maintains sibling positions, but #{model.name} has no `position` column, " \
        "so the applier would write it with `save` and leave its sequence with a gap"
      assert_equal declared_hierarchy(controller), DraftApplier.hierarchical?(model),
        "#{controller.name} says whether #{model.name}'s siblings are scoped by a parent; the applier reads it " \
        "from the model's own `parent_id` column, and the two must agree"
    end
  end

  test "every content model the applier orders has a controller that declares it" do
    # The other direction, which is the one that catches a model: a `position`
    # column nobody maintains is a sequence the applier would normalize and no
    # controller would.
    ordered_by_applier = Ability::CONTENT_CLASS_NAMES.select { |name| DraftApplier.ordered?(name.constantize) }.sort
    ordered_by_controller = positioned_controllers.filter_map { |controller| ordered_model(controller).name }.sort

    assert_equal ordered_by_applier, ordered_by_controller
  end

  test "the applier orders a model the way its controller does, for a flat sequence and a hierarchy" do
    assert DraftApplier.ordered?(Scene), "a Scene's narrative order is a flat sequence the service maintains"
    assert_not DraftApplier.hierarchical?(Scene), "a Scene has no parent: its siblings are the whole story"
    assert DraftApplier.hierarchical?(Section), "a Section's siblings are scoped by its parent"

    assert_not DraftApplier.ordered?(Relation), "a Relation has no position column and no controller that claims one"
    assert_not DraftApplier.ordered?(SceneCharacter), "a presence link is a statement, not an ordered row"
  end

  # Applying, without a request around it.

  test "it writes the draft's changes in the order they were remembered and reports each one" do
    draft = draft_with(
      change(action: "create", type: "Character", payload: { "name" => "First", "universe_id" => @universe.id }),
      change(action: "update", record: @character, payload: { "name" => "Renamed" }),
      change(action: "delete", record: locations(:location_one))
    )

    result = DraftApplier.new(draft).apply

    assert_predicate result, :complete?
    assert_equal 3, result.applied_count
    assert_equal 0, result.skipped_count
    assert_equal [ "create", "update", "delete" ], result.applied.map(&:action)
    assert Character.find_by(name: "First").present?
    assert_equal "Renamed", @character.reload.name
    assert_predicate draft.reload, :applied?
  end

  test "a change that cannot be written is reported with its reason and does not stop the others" do
    draft = draft_with(
      change(action: "update", record: @character, payload: { "name" => "Renamed" }),
      change(action: "create", type: "Character", payload: { "name" => "", "universe_id" => @universe.id })
    )

    result = DraftApplier.new(draft).apply

    assert_not_predicate result, :complete?
    assert_equal 1, result.applied_count
    assert_equal :refused, result.skipped.first.reason
    assert_equal "Renamed", @character.reload.name, "the change the universe could write is still written"
  end

  # What the detector decides, as this service sees it: a change it does not call
  # writable is reported under its own state and nothing is written. Which
  # *states* there are, and why a record somebody has deleted is not the same answer
  # as a record that was never there, is `test/services/draft_conflict_detector_test.rb`.

  test "an update whose record somebody has deleted is reported as deleted, not written onto a hidden row" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))
    @character.soft_delete

    result = DraftApplier.new(draft).apply

    assert_equal :deleted, result.skipped.first.reason
    assert_equal "Character one", @character.reload.name, "a deleted record is not written through"
    assert_predicate @character, :deleted?, "and it stays deleted"
    assert_predicate draft.reload, :applied?
  end

  test "a delete whose record is already deleted needs no write and is reported rather than claimed" do
    location = locations(:location_one)
    draft = draft_with(change(action: "delete", record: location))
    location.soft_delete

    result = DraftApplier.new(draft).apply

    # Nothing was written, so it is not claimed as applied: the applier reports what
    # it wrote. The author's intent already holds, which is why the detector does not
    # call this a conflict.
    assert_equal :gone, result.skipped.first.reason
    assert_equal 0, result.applied_count
    assert_predicate location.reload, :deleted?
  end

  test "every skip reason is one this service names" do
    assert_equal %i[moved deleted missing gone unplaceable refused], DraftApplier::SKIP_REASONS
  end

  test "a create whose stored scope is another universe is unplaceable rather than written here" do
    draft = draft_with(change(action: "create", type: "Character",
      payload: { "name" => "Out of place", "universe_id" => universes(:universe_two).id }))

    result = DraftApplier.new(draft).apply

    assert_equal :unplaceable, result.skipped.first.reason
    assert_nil universes(:universe_two).characters.find_by(name: "Out of place")
  end

  test "a create of a story-scoped record whose story is gone is unplaceable rather than written elsewhere" do
    draft = draft_with(change(action: "create", type: "Scene",
      payload: { "name" => "Orphaned", "story_id" => 0 }))

    result = DraftApplier.new(draft).apply

    assert_equal :unplaceable, result.skipped.first.reason
    assert_nil Scene.find_by(name: "Orphaned")
  end

  # A remembered create names no record, so applying the same draft twice would
  # write the author a second copy of it. The transaction is what makes the
  # invariant hold when something goes wrong half way through: a draft that is
  # still open is never a draft that is partly written.

  test "an unexpected failure rolls the whole run back and leaves the draft open" do
    draft = draft_with(
      change(action: "create", type: "Character", payload: { "name" => "Written first", "universe_id" => @universe.id }),
      # A payload this application cannot describe: an attribute no column holds.
      # `DraftMutation` cannot produce one, so it is a defect rather than
      # something the author typed — and a defect must not leave a half-written
      # universe behind a draft that still looks applyable.
      change(action: "update", record: @character, payload: { "no_such_column" => "boom" })
    )

    assert_raises(ActiveRecord::UnknownAttributeError) { DraftApplier.new(draft).apply }

    assert_nil Character.find_by(name: "Written first"), "the first change must be rolled back with the run"
    assert_not_equal "boom", @character.reload.name
    assert_predicate draft.reload, :draft?, "an apply that did not finish must leave the draft applyable"
  end

  test "a change naming a type outside the content registry is refused rather than guessed at" do
    # `DraftChange` refuses to store an unregistered type, so this is a corrupt row
    # rather than something an author did.
    update = Draft.create!(user: @user, universe: @universe)
    update.draft_changes.create!(action: "update", record_type: "Character", record_id: @character.id,
      base_version: DraftChange.capture_base_version(@character), payload: { "name" => "X" })
      .update_column(:record_type, "Session")
    # The apply above closed `update`, which is what frees the slot for the one open
    # draft per author per universe (ADR 0022), so the second draft can be opened.
    # An update names a record, so an unresolvable type is reported: there is
    # nothing to write, and reporting it is what the author can act on.
    result = DraftApplier.new(update).apply

    assert_equal 1, result.skipped_count
    assert_equal :missing, result.skipped.first.reason
    assert_predicate update.reload, :applied?

    # The apply closed `update`, which is what frees the slot for this author's one
    # open draft (ADR 0022), so the second can be opened at all.
    creating = Draft.create!(user: @user, universe: @universe)
    creating.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Y", "universe_id" => @universe.id }).update_column(:record_type, "Session")

    # A create needs the class to build anything at all, so there is no answer to
    # report: it raises, and the run's transaction is what makes that safe.
    assert_raises(ActiveRecord::RecordNotFound) { DraftApplier.new(creating).apply }
    assert_predicate creating.reload, :draft?, "a refusal that raised must leave nothing behind"
  end

  private
    # Every controller the route set reaches, so a new one is covered without
    # this file knowing it exists.
    def routed_controllers
      Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq.filter_map do |name|
        "#{name}_controller".camelize.safe_constantize
      end
    end

    def positioned_controllers
      routed_controllers.select { |controller| controller.include?(MaintainsSiblingPositions) }
    end

    def ordered_model(controller)
      controller.new.send(:sibling_position_resource_name).to_s.classify.constantize
    end

    def declared_hierarchy(controller)
      controller.new.send(:sibling_position_hierarchical?)
    end

    def draft_with(*changes)
      Draft.create!(user: @user, universe: @universe).tap do |draft|
        changes.each { |attributes| draft.draft_changes.create!(attributes) }
      end
    end

    def change(action:, type: nil, record: nil, payload: nil)
      creating = action == "create"

      { action: action, record_type: type || record.class.name, record_id: creating ? nil : record.id,
        base_version: creating ? nil : DraftChange.capture_base_version(record), payload: payload }
    end
end
