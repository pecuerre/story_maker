# The contract every list filter shares, extracted from the one that already
# works: the Scenes list narrows through `SceneFilter`, and the workspaces behind
# it are about to need the same thing seven more times.
#
# A list filter is a **value object**: it reads only the query keys in `PARAMS`
# and never assigns them to a model, so a filtered list stays a plain HTML GET
# and a filter has no mutation path, no mass assignment, and nothing for a CSRF
# token to protect. A subclass declares its own keys, resolves them against the
# lists its controller already loaded, and composes the narrowings below rather
# than writing its own `LIKE`, its own subquery, and its own rescue around
# `Date.iso8601`.
#
# What is deliberately **not** here is what each workspace decides for itself:
# which keys exist, what each one validates against, and the order the result is
# presented in. A filter that renumbers a positioned sequence and a filter over a
# flat universe list are the same shape and not the same decision.
#
# The rules this class holds are in [`docs/features/list_filters.md`](../docs/features/list_filters.md);
# the request side is `FilteredListQuery`, and the Scene filter's own keys and
# its narrative-order rule are in [`docs/features/scenes.md`](../docs/features/scenes.md).
class ListFilter
  # The free text of a filter is `q` in every list that has one, so the control,
  # the key, and the method that reads it cannot drift apart per workspace.
  TEXT_PARAM = :q

  class << self
    # The query keys a subclass owns. A controller permits exactly these, so a
    # request cannot carry a key the filter does not understand into its query.
    #
    # `const_defined?(_, false)` checks this class alone rather than its
    # ancestors, and the failure is `NotImplementedError` like the rest of the
    # contract: a subclass that forgot to declare its keys has the same problem
    # as one that forgot to narrow the list, and should report it the same way
    # rather than as an uninitialized constant.
    def params
      return const_get(:PARAMS) if const_defined?(:PARAMS, false)

      raise NotImplementedError, "#{name} must declare the PARAMS it owns"
    end
  end

  # Every filter reports the values it could not use, as sentences already
  # translated in the reader's language.
  attr_reader :discarded

  # The free-text value, resolved in `#resolve` by `resolve_text`.
  attr_reader :text

  def initialize(params)
    @params = params
    @discarded = []
    resolve
  end

  # A filter is active when something is **really** in effect. A value the
  # request asked for and this filter dropped is not active: the page says the
  # value was ignored rather than describing a narrowing that never happened.
  def active?
    query_params.any?
  end

  # The narrowed list, in the order this workspace presents it.
  def apply(_relation)
    raise NotImplementedError, "#{self.class} must narrow the list in #apply"
  end

  # The canonical query keys of the filters really in effect. This is the only
  # source of the filter in a link or a redirect, so a dropped value is never
  # carried into an address bar, a bookmark, or a shared link.
  def query_params
    raise NotImplementedError, "#{self.class} must answer #query_params"
  end

  private
    def resolve
      raise NotImplementedError, "#{self.class} must resolve its params in #resolve"
    end

    def resolve_text
      @text = @params[TEXT_PARAM].to_s.strip
    end

    # Free text over named columns of `table`, combined with `OR`.
    #
    # SQLite's LIKE ignores ASCII case, which is what a search box needs here.
    # `%` and `_` are escaped with an explicit ESCAPE character, so an author's
    # literal text is searched for instead of being read as a pattern.
    #
    # `table` and `columns` are the filter's own constants, never a request
    # value, and both are qualified because a narrowed relation may carry a join.
    def narrowed_by_text(relation, table:, columns:)
      return relation if text.blank?

      pattern = "%#{relation.klass.sanitize_sql_like(text)}%"
      conditions = columns.map { |column| "#{table}.#{column} LIKE :pattern ESCAPE '\\'" }

      relation.where(conditions.join(" OR "), pattern: pattern)
    end

    # A filter value is validated against the already-loaded, already-scoped list
    # the index needed anyway, so a foreign id never reaches the query and costs
    # no query of its own. A value that is not in the list is dropped and
    # reported rather than silently emptying the list.
    #
    # `allowed` holds ids or records, and `identifier` says which part of one
    # travels in the URL: a list filtered by a Section compares an id, while a
    # list filtered by a tag compares the record that id names.
    def resolve_in_list(value, allowed, discard_key, identifier: :to_s)
      raw = value.to_s.strip
      return if raw.blank?

      found = allowed.find { |candidate| candidate.public_send(identifier).to_s == raw }
      return found if found

      discard(discard_key)
      nil
    end

    # The scoped inverse association is the only way to reach the records
    # carrying a tag, so a tag filter can never disclose another story's or
    # another universe's records.
    def narrowed_by_tag(relation, tag)
      return relation if tag.nil?

      relation.where(id: tag.tagged_records.select(:id))
    end

    # A `date` input submits an ISO day or nothing, so an unreadable value only
    # arrives from a hand-edited URL. It is reported, not guessed at.
    #
    # `label_key` names the word describing this end of the range, so the
    # message names it the way the control beside the reader's hand does rather
    # than with a literal `start`/`end` this method was called with.
    def resolve_day(value, label_key:, discard_key:)
      raw = value.to_s.strip
      return if raw.blank?

      Date.iso8601(raw)
    rescue Date::Error
      discard(discard_key, bound: t(label_key), value: raw)
      nil
    end

    # The bounds are days, not instants, and both are inclusive. A record without
    # a time in `column` is excluded while a bound is set: it has no time to
    # compare, and a null is never inside a range.
    def narrowed_by_day_range(relation, column, from: nil, to: nil)
      return relation if from.nil? && to.nil?
      return relation.where(column => from.beginning_of_day..) if to.nil?
      return relation.where(column => ..to.end_of_day) if from.nil?

      relation.where(column => from.beginning_of_day..to.end_of_day)
    end

    # A value that cannot be used is dropped and **reported**, never swallowed.
    # The sentence is translated where it is dropped rather than stored as a key,
    # because the controller joins the reports with `to_sentence` and a sentence
    # assembled with English connectors is not a sentence in any other language.
    def discard(key, **options)
      @discarded << t(key, **options)
    end

    # A list filter is a value object and does not include the view's `translate`
    # helper, so these keys resolve through `I18n.t` against the request's
    # `I18n.locale` — the same call `Event`'s own `errors.add` messages make. The
    # alternative, storing keys and letting the view translate them, would mean
    # the controller had to know which of the filter's internal labels are chrome.
    def t(key, **options)
      I18n.t(key, **options)
    end
end
