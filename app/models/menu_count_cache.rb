module MenuCountCache
  CACHE_KEY_VERSION = 1
  CACHE_TTL = 1.hour
  RACE_CONDITION_TTL = 5.seconds

  class << self
    def fetch(key, connection:)
      return yield if connection.transaction_open?

      Rails.cache.fetch(key, expires_in: CACHE_TTL, race_condition_ttl: RACE_CONDITION_TTL) { yield }
    end

    def key(scope, id)
      [ "menu-counts", CACHE_KEY_VERSION, scope, id ]
    end

    def expire(scope, id)
      Rails.cache.delete(key(scope, id)) unless id.nil?
    end
  end
end
