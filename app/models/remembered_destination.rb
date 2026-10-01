# The universe and story a reader was last working in, kept across sign-outs.
#
# `set_current_story` remembers a per-universe story map in the **session**, and
# that is the right place for switching between universes inside one visit. It
# cannot answer "where was I?" after a new login, because the session is wiped
# when a session starts and ends — deliberately, so one account's story choices
# are never handed to the next account on the same browser. A reader who signs
# out and back in therefore arrives at the universes index with no idea how to
# resume.
#
# So the last destination is stored separately, in a signed cookie, and it is
# bound to the account that wrote it. The binding is the important part: an
# account switch clears the session map for exactly the reason that a shared
# browser must not carry one reader's working context into another's, and a
# destination that ignored that would put it right back.
#
# Everything read out of the cookie is re-authorized rather than trusted. A
# signed cookie cannot be forged, but it can be stale: the universe may since
# have been made private, the membership revoked, or the story deleted. Reading
# therefore resolves live records and checks access, and anything that does not
# resolve answers `nil` — the same "no destination" the reader would have got
# without the cookie.
class RememberedDestination
  COOKIE_NAME = :um_last_scope
  # Matches the session cookie's own lifetime, so the two do not disagree about
  # how long a sign-in is expected to last.
  EXPIRES_IN = 1.year

  # A resolved, authorized destination. `story` is nil when the reader was last
  # in a universe without a story selected, which is a real state: entering a
  # universe and stopping there is not the same as never having chosen one.
  Destination = Struct.new(:universe, :story, keyword_init: true)

  class << self
    # Record where this request is working. Written only when it actually
    # changes, because `set_current_story` runs on every request inside a
    # universe and a cookie write per page view would be a response header and a
    # `Set-Cookie` on every one of them.
    def remember(cookies, user:, universe:, story: nil)
      return if user.nil? || universe.nil?
      return if unchanged?(cookies, user: user, universe: universe, story: story)

      write(cookies, user: user, universe: universe, story: story)
    end

    def write(cookies, user:, universe:, story: nil)
      cookies.signed[COOKIE_NAME] = {
        value: payload(user: user, universe: universe, story: story).to_json,
        expires: EXPIRES_IN.from_now,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
    end

    def clear(cookies)
      cookies.delete(COOKIE_NAME)
    end

    # The remembered destination for this reader, or nil when there is none this
    # reader may open. `nil` covers every way it can fail: no cookie, a cookie
    # that cannot be parsed, a cookie written by a different account, a universe
    # or story that no longer exists, and a universe this account may no longer
    # read.
    def for(cookies, user:)
      stored = read(cookies)
      return if stored.nil?
      return if user.nil? || stored[:user_id] != user.id

      universe = Universe.find_by(slug: stored[:universe_slug])
      return if universe.nil? || !universe.readable_by?(user)

      Destination.new(universe: universe, story: find_story(universe, stored[:story_id]))
    end

    # The stored value, or nil when there is nothing usable there. The cookie
    # holds JSON rather than a serialized object, so what is read back is a
    # plain string this class parses itself — the value's shape is stated here
    # instead of depending on how a cookie jar happens to round-trip an object.
    def read(cookies)
      value = cookies.signed[COOKIE_NAME]
      return if value.blank?

      stored = value.is_a?(String) ? JSON.parse(value) : value
      return unless stored.is_a?(Hash)

      stored.symbolize_keys.slice(:user_id, :universe_slug, :story_id)
        .tap { |parsed| return if parsed[:universe_slug].blank? }
    rescue JSON::ParserError
      nil
    end

    private
      def payload(user:, universe:, story:)
        { user_id: user.id, universe_slug: universe.slug, story_id: story&.id }
      end

      def unchanged?(cookies, user:, universe:, story:)
        stored = read(cookies)
        return false if stored.nil?

        stored[:user_id] == user.id &&
          stored[:universe_slug] == universe.slug &&
          stored[:story_id] == story&.id
      end

      # A story that has been soft-deleted resolves to nil here, which is the
      # universe alone rather than a dead link. A story belonging to another
      # universe cannot be found through this universe's own collection, so a
      # tampered id resolves to nothing rather than to someone else's story.
      def find_story(universe, story_id)
        return if story_id.blank?

        universe.stories.find_by(id: story_id)
      end
  end
end
