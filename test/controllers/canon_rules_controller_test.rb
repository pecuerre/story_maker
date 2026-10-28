require "test_helper"

class CanonRulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "index lists every rule in the universe with its owner" do
    get universe_canon_rules_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Canon"
    assert_select ".entity-row", text: /Magic always costs the caster a memory/
    assert_select ".entity-row", text: /The river cannot be crossed at night/
    assert_select ".entity-row a[href=?]", universe_story_path(universe_slug: @universe.slug, id: @story)
    assert_select ".entity-row .badge", text: "Whole universe"
  end

  test "creates a universe-wide rule" do
    assert_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { statement: "A name spoken backwards is never forgotten.", source: "" }
      }
    end

    assert_redirected_to universe_canon_rules_url(universe_slug: @universe.slug)
    rule = CanonRule.order(:id).last
    assert_predicate rule, :universe_wide?
    assert_predicate rule.source, :blank?
  end

  test "creates a rule owned by a story" do
    post universe_canon_rules_url(universe_slug: @universe.slug), params: {
      canon_rule: { statement: "Only the ferryman may cross at night.", story_id: @story.id }
    }

    assert_redirected_to universe_canon_rules_url(universe_slug: @universe.slug)
    assert_equal @story, CanonRule.order(:id).last.story
  end

  test "updates a rule and can hand it back to the universe" do
    rule = canon_rules(:canon_rule_two)

    patch universe_canon_rule_url(universe_slug: @universe.slug, id: rule), params: {
      canon_rule: { statement: rule.statement, story_id: "" }
    }

    assert_response :see_other
    assert_predicate rule.reload, :universe_wide?
  end

  test "refuses a blank statement on the list page" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { statement: "" }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /can't be blank/
  end

  test "refuses a story from another universe" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { statement: "Never here.", story_id: stories(:story_two).id }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /must belong to the same universe/
  end

  test "refuses a story id that names nothing" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { statement: "Never anywhere.", story_id: 999_999 }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /does not exist/
  end

  test "soft deletes a rule" do
    rule = canon_rules(:canon_rule_one)

    delete universe_canon_rule_url(universe_slug: @universe.slug, id: rule)

    assert_response :see_other
    assert_predicate rule.reload, :deleted?
  end

  test "shows the rule's statement, source, and owner" do
    get universe_canon_rule_url(universe_slug: @universe.slug, id: canon_rules(:canon_rule_two))

    assert_response :success
    assert_select "h1", text: "The river cannot be crossed at night."
    assert_select ".detail-facts-wide", text: /Chapter five/
    assert_select "a[href=?]", universe_story_path(universe_slug: @universe.slug, id: @story)
  end

  test "a rule from another universe is not found" do
    rule = CanonRule.create!(universe: universes(:universe_two), statement: "Elsewhere only.")

    get universe_canon_rule_url(universe_slug: @universe.slug, id: rule)

    assert_response :not_found
  end

  test "a guest may read the list and a rule" do
    sign_out

    get universe_canon_rules_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "button[data-action='modal-form#open']", 0

    get universe_canon_rule_url(universe_slug: @universe.slug, id: canon_rules(:canon_rule_one))
    assert_response :success
  end
end
