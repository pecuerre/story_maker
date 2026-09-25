module InvalidatesMenuCounts
  extend ActiveSupport::Concern

  class_methods do
    # `scope` names the owning association. `cache_scope` names the cache entry
    # that holds the count for that scope; it defaults to the association but
    # must differ when one owner already caches a second scalar metric under
    # the same key (Story caches both its section and its scene count).
    def invalidates_menu_counts_for(scope, cache_scope: nil)
      @menu_count_scope = scope
      @menu_count_cache_scope = cache_scope || scope
    end

    def menu_count_scope
      @menu_count_scope
    end

    def menu_count_cache_scope
      @menu_count_cache_scope
    end
  end

  included do
    before_create :track_menu_count_for_invalidation
    before_destroy :track_menu_count_for_invalidation
    before_update :track_menu_count_scope_changes
    # Savepoint rollbacks also run after_rollback, so tracked outer-transaction scopes stay here.
    after_commit :invalidate_menu_counts, on: %i[ create destroy update ]
  end

  private
    def invalidate_menu_counts
      scope_ids = tracked_menu_count_scope_ids
      return if scope_ids.empty?

      scope_ids << menu_count_scope_id
      scope_ids.compact.uniq.each do |scope_id|
        MenuCountCache.expire(menu_count_cache_scope, scope_id)
      end
    ensure
      clear_tracked_menu_counts
    end

    def track_menu_count_for_invalidation
      track_menu_count_scope_ids([ menu_count_scope_id ])
    end

    def track_menu_count_scope_changes
      scope_change = pending_menu_count_scope_change
      track_menu_count_scope_ids(scope_change) if scope_change
    end

    def track_menu_count_scope_ids(scope_ids)
      @menu_count_scope_ids_to_invalidate ||= []
      @menu_count_scope_ids_to_invalidate.concat(scope_ids)
    end

    def tracked_menu_count_scope_ids
      @menu_count_scope_ids_to_invalidate || []
    end

    def clear_tracked_menu_counts
      @menu_count_scope_ids_to_invalidate = nil
    end

    def menu_count_scope
      self.class.menu_count_scope
    end

    def menu_count_cache_scope
      self.class.menu_count_cache_scope
    end

    def menu_count_scope_id
      public_send("#{menu_count_scope}_id")
    end

    def pending_menu_count_scope_change
      public_send("#{menu_count_scope}_id_change")
    end
end
