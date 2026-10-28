# Resolves the Universe that owns a content record.
#
# Universe authorization and the shared view helpers must agree: if they
# disagree, a writer can see missing mutation controls, or a record-level check
# can deny a mutation the universe policy allows. Both call this one resolver
# so they cannot drift.
#
# A record reaches its Universe either directly (`Universe#universe` or
# `Scene#universe`), or through one of the declared owner associations below:
# `story` for story-scoped records, `scene` for Scene components, `section` for
# Section-owned records, and `scene_element` for components nested under an
# Element. The walk is explicit and bounded rather than a generic association
# crawl, so a record can never resolve to the wrong universe by accident.
#
# A nested model should define its own `universe` method when the record-level walk
# needs another hop. Its owner association also belongs in this list when the
# class-level SQL walk must filter records through that owner.
module UniverseScopeResolver
  OWNER_ASSOCIATIONS = %i[ story scene section scene_element ].freeze

  # Raised when a model is asked which of its rows belong to a universe and there
  # is no column to ask with: the model has neither a `universe_id` of its own nor
  # one of the owner associations above. A model in that position is nested below
  # something the walk does not name — a speaker link under a Scene Element, for
  # instance — and it has to say so by defining its own `#universe` to delegate
  # through its owner.
  #
  # The walk itself cannot raise this, because `universe_for` is also asked of
  # unsaved records and of records whose owner row is gone, where `nil` is the
  # correct answer. `records_in` is asked of a *class*, before any record exists,
  # so a model it cannot place is a model that never declared where it lives.
  class UnresolvableModel < StandardError; end

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
    # A model that carries its own `universe_id` is placed by that column even
    # when it also names a narrower owner. A Canon Rule is the first: it belongs
    # to the universe and *optionally* to a story, so `story_id` is a reference
    # rather than the record's scope, and a rule with no story would fall out of a
    # scope walk that filtered by it. So the direct column is asked first, and the
    # owner associations are only consulted when there is none.
    return nil if model.column_names.include?("universe_id")

    OWNER_ASSOCIATIONS.find do |association|
      model.column_names.include?("#{association}_id")
    end
  end

  # The rows of `model` that belong to `universe`, for a question asked before
  # there is a record: an authorization check against the class rather than
  # against a row. It is `universe_for` walked in SQL instead of in memory, the
  # same `owner_association_for` answer one hop at a time, so a class-level check
  # and a record-level one reach the universe by the same route and cannot
  # disagree about which rows are in scope.
  #
  # The walk is bounded the way `universe_for`'s is. Each hop moves up — a Scene
  # to its Story, a Story to its `universe_id` — and a model that reaches its
  # universe directly has no owner association to take.
  #
  # It is asked of a model that *is* its own universe — `Universe` — as nothing:
  # that record is the universe, so there is no column to filter on and the caller
  # answers from the universe it already holds. Asking anyway raises
  # `UnresolvableModel` rather than reaching the database, which is what the
  # short-circuit in `Ability#class_answer` exists to avoid.
  #
  # A model that is neither its own universe nor one hop from one cannot be
  # filtered at all, and says so by name rather than by reaching the database and
  # being refused for a column that does not exist.
  def records_in(model, universe)
    owner = owner_association_for(model)

    if owner
      model.where(owner => records_in(model.reflect_on_association(owner).klass, universe).select(:id))
    elsif model.column_names.include?("universe_id")
      model.where(universe_id: universe.id)
    else
      raise UnresolvableModel, unplaceable_model_message(model)
    end
  end

  # Two different mistakes reach the same raise, and they are not fixed the same
  # way. A model that never declared its scope needs `#universe`. A model that did
  # declare it still cannot be filtered here, because this walks in SQL and a
  # delegation is Ruby — that model needs a column, or it needs to stay out of the
  # content registry so no class-level check is ever asked of it.
  def unplaceable_model_message(model)
    name = model.name || model.table_name
    through = "reaches its universe through neither a universe_id column nor a " \
      "#{OWNER_ASSOCIATIONS.join('/')} association, so there is no column to filter it by."

    if model.method_defined?(:universe)
      "#{name} #{through} It declares #universe, which answers the record-level walk, but this filters in " \
        "SQL and a delegation cannot be filtered: give it a column, or keep it out of the content registry " \
        "so no class-level check is asked of it."
    else
      "#{name} #{through} It is nested below a model the walk does not name: define #universe on it to " \
        "delegate through its owner, and record-level checks and rendered controls will both find it."
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
