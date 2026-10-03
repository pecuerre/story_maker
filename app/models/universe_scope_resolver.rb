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

  # The owner association a model reaches its universe through, or nil when it
  # reaches it directly and so has no owner association at all.
  #
  # It is asked of a *class* rather than of a record because three callers need
  # the answer before there is a record: `DraftMutation` choosing the one column to
  # store alongside a remembered create, `DraftApplier` choosing the collection to
  # order when it writes that create, and `DraftChange` naming the column again so
  # a draft's own page can tell plumbing from something it can print. Reading the
  # model's columns is what keeps those three answers one answer.
  def owner_association_for(model)
    OWNER_ASSOCIATIONS.find do |association|
      model.column_names.include?("#{association}_id")
    end
  end

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
