# Resolves the Universe that owns a content record.
#
# Universe authorization and the shared view helpers must agree: if they
# disagree, a writer can see missing mutation controls, or a record-level check
# can deny a mutation the universe policy allows. Both call this one resolver
# so they cannot drift.
#
# A record reaches its Universe either directly (`Universe#universe` or
# `Scene#universe`), or through one of the declared owner associations below:
# `story` for story-scoped records, `scene` for Scene components, and `section`
# for anything a Section owns. The walk is explicit and bounded rather than a
# generic association crawl, so a record can never resolve to the wrong universe
# by accident.
#
# A model that owns something deeper than one of those associations — a speaker
# link belonging to a Scene Element, for example — should define its own
# `universe` method that delegates through its owner. The first line of the walk
# then finds it, and no new entry is needed here.
module UniverseScopeResolver
  OWNER_ASSOCIATIONS = %i[ story scene section ].freeze

  module_function

  def universe_for(record, visited = [])
    return if record.nil?
    return record.universe if record.respond_to?(:universe)
    return if visited.any? { |seen| seen.equal?(record) }

    visited += [ record ]
    OWNER_ASSOCIATIONS.each do |association|
      next unless record.respond_to?(association)

      universe = universe_for(record.public_send(association), visited)
      return universe if universe
    end

    nil
  end
end
