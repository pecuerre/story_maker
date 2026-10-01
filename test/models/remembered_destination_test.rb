require "test_helper"

# The remembered destination is a signed cookie, so it cannot be forged — but it
# can be stale, and it is stored outside the session that the rest of the
# authentication code deliberately clears on every sign-in and sign-out. These
# cases are about what it answers when it should answer nothing.
class RememberedDestinationTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a remembered universe and story resolve for the account that stored them" do
    jar = remember(universe: @universe, story: @story)

    destination = RememberedDestination.for(jar, user: @user)

    assert_equal @universe, destination.universe
    assert_equal @story, destination.story
  end

  # Stopping in a universe without choosing a story is a real state, and it
  # resolves to the universe alone rather than to no destination at all.
  test "a remembered universe with no story resolves to the universe alone" do
    jar = remember(universe: @universe, story: nil)

    destination = RememberedDestination.for(jar, user: @user)

    assert_equal @universe, destination.universe
    assert_nil destination.story
  end

  # The binding to an account is the point. The session story map is wiped on
  # every sign-in for exactly this reason, so a destination that ignored it would
  # hand one account's working context to the next account on the same browser.
  test "a destination stored by another account is not returned" do
    jar = remember(universe: @universe, story: @story)

    assert_nil RememberedDestination.for(jar, user: users(:user_two))
    assert_nil RememberedDestination.for(jar, user: nil)
  end

  test "no cookie answers no destination" do
    jar = ActionDispatch::TestRequest.create.cookie_jar

    assert_nil RememberedDestination.for(jar, user: @user)
  end

  # A signed cookie can still be out of date. These are the three ways a stored
  # universe stops being openable, and each must answer nil rather than produce
  # a link to a page this account cannot read.
  test "a universe that has since been made private answers no destination" do
    jar = remember(universe: @universe, story: @story)
    @universe.update!(private: true)

    assert_nil RememberedDestination.for(jar, user: users(:user_two))
    # The owner and an admin membership still reach it.
    assert_equal @universe, RememberedDestination.for(jar, user: @user).universe
  end

  test "a membership that has been revoked answers no destination" do
    universe = Universe.create!(owner: users(:user_two), name: "Private to user two", slug: "private-two", private: true)
    membership = UniverseMembership.create!(universe: universe, user: @user, access_level: :write)
    jar = remember(universe: universe, story: nil)
    assert_equal universe, RememberedDestination.for(jar, user: @user).universe

    membership.destroy!

    assert_nil RememberedDestination.for(jar, user: @user)
  end

  test "a universe or story that no longer exists answers no destination" do
    jar = remember(universe: @universe, story: @story)

    @story.soft_delete

    destination = RememberedDestination.for(jar, user: @user)
    assert_equal @universe, destination.universe
    assert_nil destination.story, "a deleted story is not a landing page; the universe still is"
  end

  # A story id belonging to a different universe cannot be resolved through this
  # universe's own collection, so a tampered id finds nothing rather than
  # reaching someone else's story.
  test "a story id from another universe is not resolved" do
    other_story = stories(:story_two)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    RememberedDestination.write(jar,
      user: @user, universe: @universe, story: other_story)

    destination = RememberedDestination.for(jar, user: @user)

    assert_equal @universe, destination.universe
    assert_nil destination.story
  end

  # `set_current_story` runs on every request inside a universe, so a write that
  # changed nothing would put a Set-Cookie header on every page view.
  test "remembering the same destination twice writes no second cookie" do
    jar = ActionDispatch::TestRequest.create.cookie_jar

    RememberedDestination.remember(jar, user: @user, universe: @universe, story: @story)
    written = jar.instance_variable_get(:@set_cookies)[RememberedDestination::COOKIE_NAME.to_s]

    RememberedDestination.remember(jar, user: @user, universe: @universe, story: @story)

    assert_same written, jar.instance_variable_get(:@set_cookies)[RememberedDestination::COOKIE_NAME.to_s],
      "an unchanged destination does not rewrite the cookie"
    assert_equal 1, jar.instance_variable_get(:@set_cookies).size
  end

  test "remembering a different destination rewrites the cookie" do
    jar = ActionDispatch::TestRequest.create.cookie_jar
    RememberedDestination.remember(jar, user: @user, universe: @universe, story: @story)

    RememberedDestination.remember(jar, user: @user, universe: universes(:universe_two), story: nil)

    assert_equal universes(:universe_two), RememberedDestination.for(jar, user: @user).universe
    assert_equal 1, jar.instance_variable_get(:@set_cookies).size,
      "the cookie is rewritten in place rather than added beside itself"
  end

  test "a guest has no destination to remember" do
    jar = ActionDispatch::TestRequest.create.cookie_jar

    RememberedDestination.remember(jar, user: nil, universe: @universe, story: @story)

    assert_nil RememberedDestination.for(jar, user: @user)
  end

  test "clear removes the stored destination" do
    jar = remember(universe: @universe, story: @story)
    assert_not_nil RememberedDestination.for(jar, user: @user)

    RememberedDestination.clear(jar)

    assert_nil RememberedDestination.for(jar, user: @user)
  end

  test "an unsigned cookie is not a destination" do
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar[RememberedDestination::COOKIE_NAME] = { user_id: @user.id, universe_slug: @universe.slug }.to_json

    assert_nil RememberedDestination.for(jar, user: @user)
  end

  private
    def remember(universe:, story:)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      RememberedDestination.write(jar, user: @user, universe: universe, story: story)
      jar
    end
end
