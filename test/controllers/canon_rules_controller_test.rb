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
    assert_select ".entity-row .entity-title", text: "Magic costs a memory"
    assert_select ".entity-row .entity-title", text: "The night crossing"
    assert_select ".entity-row", text: /Magic always costs the caster a memory/
    assert_select ".entity-row .badge", text: "Locked"
    assert_select ".entity-row .badge", text: "magic"
    assert_select ".entity-row a[href=?]", universe_story_path(universe_slug: @universe.slug, id: @story)
    assert_select ".entity-row .badge", text: "Whole universe"
  end

  test "the list leads with the rule's ledger id" do
    get universe_canon_rules_url(universe_slug: @universe.slug)

    assert_select ".entity-row code.canon-rule-id", text: "K1"
    assert_select ".entity-row code.canon-rule-id", text: "L2"
    # The id is the first thing in the row, before the name.
    first_row = css_select(".entity-row").first
    assert_equal "K1", first_row.at_css(".entity-copy > .d-flex > *").text
  end

  test "a reference in a row's prose is named as plain text, not a link" do
    canon_rules(:canon_rule_two).update!(source: "The ferryman quotes [[canon:K1]] before dark.")

    get universe_canon_rules_url(universe_slug: @universe.slug)

    assert_select ".entity-row .entity-description", text: /quotes K1 before dark/
    assert_select ".entity-row .entity-description a", text: "K1", count: 0
  end

  test "the list narrows by text, canon type, owner, and order" do
    get universe_canon_rules_url(universe_slug: @universe.slug, q: "memory")
    assert_select ".entity-row .entity-title", count: 1, text: "Magic costs a memory"
    assert_select ".canon-rule-filter", text: /Showing 1 rule of 2 rules/

    get universe_canon_rules_url(universe_slug: @universe.slug, canon_type: "rule")
    assert_select ".entity-row .entity-title", count: 1, text: "The night crossing"

    get universe_canon_rules_url(universe_slug: @universe.slug, owner_story_id: @story.id)
    assert_select ".entity-row .entity-title", count: 1, text: "The night crossing"

    get universe_canon_rules_url(universe_slug: @universe.slug, owner_story_id: CanonRuleFilter::UNIVERSE_SCOPE)
    assert_select ".entity-row .entity-title", count: 1, text: "Magic costs a memory"

    get universe_canon_rules_url(universe_slug: @universe.slug, sort: "updated")
    assert_select ".entity-row .entity-title", text: "Magic costs a memory"
    assert_select ".canon-rule-filter", text: /Order: Recently edited first/
  end

  test "a blank filter field redirects to the canonical list" do
    get universe_canon_rules_url(universe_slug: @universe.slug, q: "", canon_type: "", owner_story_id: "", sort: "name")

    assert_redirected_to universe_canon_rules_url(universe_slug: @universe.slug)
  end

  test "a filter that matched nothing is not an empty universe" do
    get universe_canon_rules_url(universe_slug: @universe.slug, q: "no such rule")

    assert_response :success
    assert_select ".empty-title", text: "No canon rules match these filters"
    assert_select ".empty-description", text: /Universe one has 2 rules/
    assert_select ".badge", text: /Search: “no such rule”/
    assert_select "a", text: "Clear filters"
  end

  test "a mutation returns to the narrowed list it was performed from" do
    rule = canon_rules(:canon_rule_one)

    delete universe_canon_rule_url(universe_slug: @universe.slug, id: rule, q: "memory")

    assert_redirected_to universe_canon_rules_url(universe_slug: @universe.slug, q: "memory")
  end

  test "creates a universe-wide rule" do
    assert_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { name: "A name spoken backwards", statement: "A name spoken backwards is never forgotten.", source: "" }
      }
    end

    assert_redirected_to universe_canon_rules_url(universe_slug: @universe.slug)
    rule = CanonRule.order(:id).last
    assert_predicate rule, :universe_wide?
    assert_predicate rule.source, :blank?
    assert_equal "a-name-spoken-backwards", rule.slug
  end

  test "creates a rule owned by a story" do
    post universe_canon_rules_url(universe_slug: @universe.slug), params: {
      canon_rule: { name: "The ferryman's rule", statement: "Only the ferryman may cross at night.", story_id: @story.id }
    }

    assert_redirected_to universe_canon_rules_url(universe_slug: @universe.slug)
    assert_equal @story, CanonRule.order(:id).last.story
  end

  test "creates a rule with a ledger id, a category, and a canon type" do
    post universe_canon_rules_url(universe_slug: @universe.slug), params: {
      canon_rule: { name: "Trigger", slug: "L7", category: "mechanism", canon_type: "rule",
        statement: "The mechanism starts when the wheel turns." }
    }

    rule = CanonRule.order(:id).last

    assert_equal "l7", rule.slug
    assert_equal "mechanism", rule.category
    assert_equal "rule", rule.canon_type
  end

  test "updates a rule and can hand it back to the universe" do
    rule = canon_rules(:canon_rule_two)

    patch universe_canon_rule_url(universe_slug: @universe.slug, id: rule), params: {
      canon_rule: { name: rule.name, statement: rule.statement, story_id: "" }
    }

    assert_response :see_other
    assert_predicate rule.reload, :universe_wide?
  end

  test "refuses a blank name on the list page" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { name: "", statement: "A rule with no title." }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /can't be blank/
  end

  test "refuses a blank statement on the list page" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { name: "A title with no rule", statement: "" }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /can't be blank/
  end

  test "refuses a story from another universe" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { name: "Nowhere", statement: "Never here.", story_id: stories(:story_two).id }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /must belong to the same universe/
  end

  test "refuses a story id that names nothing" do
    assert_no_difference("CanonRule.count") do
      post universe_canon_rules_url(universe_slug: @universe.slug), params: {
        canon_rule: { name: "Nowhere", statement: "Never anywhere.", story_id: 999_999 }
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

  test "shows the rule's name, slug, type, category, statement, source, and owner" do
    get universe_canon_rule_url(universe_slug: @universe.slug, id: canon_rules(:canon_rule_two))

    assert_response :success
    assert_select "h1", text: "The night crossing"
    assert_select ".detail-facts", text: /l2/
    assert_select ".detail-facts", text: /Rule/
    assert_select ".detail-facts-wide", text: /The river cannot be crossed at night/
    assert_select ".detail-facts-wide", text: /Chapter five/
    assert_select "a[href=?]", universe_story_path(universe_slug: @universe.slug, id: @story)
  end

  test "the details page reads the statement and source as Markdown with references" do
    rule = canon_rules(:canon_rule_two)
    rule.update!(
      statement: "The river cannot be crossed at night.\n\nSee [[canon:K1]] for what the crossing costs.",
      source: "Chapter five.\n\nThe ferryman quotes [[canon:K1]] before dark."
    )

    get universe_canon_rule_url(universe_slug: @universe.slug, id: rule)

    assert_response :success
    # A blank line is a paragraph, which is how an imported item's what-line and
    # body stay two blocks instead of one run-on line.
    assert_select ".detail-facts-wide p", text: "Chapter five."
    assert_select ".detail-facts-wide p", text: "The ferryman quotes K1 before dark."
    assert_select ".detail-facts-wide a[href=?]",
      universe_canon_rule_path(universe_slug: @universe.slug, id: canon_rules(:canon_rule_one)),
      text: "K1", count: 2
  end

  test "a writer's details page opens the rule editor in place" do
    rule = canon_rules(:canon_rule_two)

    get universe_canon_rule_url(universe_slug: @universe.slug, id: rule)

    assert_response :success
    assert_select "[data-controller~='modal-form'][data-modal-form-response-value='html']", 1
    assert_select ".page-actions button[data-action='modal-form#open'][data-modal-form-method='patch']" \
      "[data-modal-form-url=?]", universe_canon_rule_path(universe_slug: @universe.slug, id: rule), count: 1
    assert_select "form[action=?] input[name='_method'][value='patch']",
      universe_canon_rule_path(universe_slug: @universe.slug, id: rule), count: 1
    assert_select "form[action=?] input[name='return_to'][value='details']",
      universe_canon_rule_path(universe_slug: @universe.slug, id: rule), count: 1

    values = JSON.parse(Nokogiri::HTML(response.body)
      .at_css("button[data-action='modal-form#open'][data-modal-form-record-id]")
      .attribute("data-modal-form-values-value").value)
    assert_equal rule.name, values.fetch("name")
    assert_equal rule.statement, values.fetch("statement")
  end

  test "an update from the details page returns to the rule" do
    rule = canon_rules(:canon_rule_two)

    patch universe_canon_rule_url(universe_slug: @universe.slug, id: rule),
      params: { canon_rule: { name: rule.name, statement: "The river is crossed only at dawn." }, return_to: "details" }

    assert_redirected_to universe_canon_rule_url(universe_slug: @universe.slug, id: rule)
    assert_equal "The river is crossed only at dawn.", rule.reload.statement
  end

  test "a refused update from the details page keeps the rule page" do
    rule = canon_rules(:canon_rule_two)
    path = universe_canon_rule_url(universe_slug: @universe.slug, id: rule)

    patch path, params: { canon_rule: { name: "", statement: rule.statement }, return_to: "details" }

    assert_response :unprocessable_content
    assert_select "h1", text: rule.statement
    assert_select ".alert-danger", text: /can't be blank/
    assert_select "form[action=?] input[name='return_to'][value='details']",
      universe_canon_rule_path(universe_slug: @universe.slug, id: rule), count: 1
  end

  test "a rule from another universe is not found" do
    rule = CanonRule.create!(universe: universes(:universe_two), name: "Elsewhere", statement: "Elsewhere only.")

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
    assert_select "[data-controller~='modal-form']", 0
    assert_select "button[data-action='modal-form#open']", 0
    assert_select "[data-modal-form-target='modal']", 0
  end
end
