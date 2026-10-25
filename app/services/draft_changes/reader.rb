# Reads one draft's remembered changes in a fixed number of queries.
#
# **This is the read side of finding 66.** A draft's page, a reviewer's page, and the
# sidebar's pending panel all print the same three facts about each change — which record
# it names, what the ids in its payload call, and which story or section it would be
# written under — and all three used to be a query per change: `DraftChange#resolved_record`
# asks `RecordTarget` one row at a time, `DraftsHelper#association_names` asked the tag table one
# id at a time, and the scope column was dropped from the page rather than resolved. A draft
# assembled from a long editing session therefore cost a query per row, and the sidebar panel
# pays it on **every page** of the universe.
#
# **Grouped by class, not by row.** Both answers are "these ids, of this class", so this
# object asks once per class rather than once per id: one query for every `Character` a
# draft's changes name, one for every `CharacterTag` those changes' payloads carry. The
# number of queries is therefore the number of *classes a draft touches*, which is bounded
# by the models in one universe rather than by how long the author has been editing.
#
# **It answers the same questions, through the same gates, as the per-row reads it
# replaces.** Records go through `RecordTarget.model_for`, so the content registry still
# decides which `record_type` may be loaded and an unregistered one is still no record
# rather than a `NameError`; a record that no longer resolves is still absent, because a
# draft's page has to render a change whose record somebody has since deleted. Tag ids
# are resolved through the association's own class, and an id that no longer names a tag
# is still dropped rather than printed, because the change it was part of is the author's
# statement about the ids that are still there. **Soft-deleted rows stay invisible**: the
# class's default scope applies exactly as it does to a single `find_by`, so batching
# cannot turn a deleted tag into a name the per-row read would have refused to print.
#
# **One instance per request, and the memoization lives on the object.** The sidebar panel
# and the page beside it ask the same questions about the same draft within one render, so
# building this twice would double the queries it exists to reduce. Nothing here outlives
# the request that built it, which is the same lifetime `Current` itself has.
#
# **A create names no record, and asking anyway is a query that cannot answer.**
# `resolved_record` on a remembered create is `RecordTarget.find` with a nil id, which
# issues `WHERE id IS NULL` and returns nothing — the finding's second, smaller cost.
# This class refuses to ask: `record_for` answers nil for a create without touching the
# database, and the panel's `change.creating?` guard becomes redundant rather than
# load-bearing.
class DraftChanges::Reader
  # One change's resolved answers, as the three things a row about it has to print.
  #
  # `tag_records` and `scope_record` hold the **records**, not their names: this class
  # answers which rows the payload's ids name, and turning a row into a word is the
  # view layer's job (`record_label`). A Reader that printed labels itself would need a
  # label ladder of its own, and ADR 0023 rejected exactly that second copy.
  Entry = Data.define(:change, :record, :tag_records, :scope_record) do
    # The tags one payload key named, or nil when the key was not an id list — which is
    # how the caller tells "no tags" from "nothing to name". An id that no longer resolves
    # is absent from the answer rather than nil-valued, because a change the author made
    # about a tag that has since been deleted is still a change they made.
    def tags_for(name)
      tag_records&.[](name)
    end

    # The stored record this change's scope column names — the Story a Scene would be
    # written under, the Section a Scene Element hangs from.
    #
    # **Nil covers two situations the caller deliberately cannot tell apart**: a
    # change whose payload named no scope id, and one whose scope record has since
    # been deleted. Both read the same way — this change does not currently say where
    # it would go — so the page states that once rather than twice. A **universe**
    # scope is not one of them: it never resolves at all, and the page prints no scope
    # row for it, which is the one case where the page is already inside the answer.
    def scope
      scope_record
    end
  end

  # @param changes [Enumerable<DraftChange>] the changes to read, in the order they will
  #   be rendered. A collection is taken as given rather than re-queried, because every
  #   caller has already loaded its changes and a second read of them would be the very
  #   cost this class exists to remove.
  def initialize(changes)
    @changes = changes.to_a
  end

  # Every change, in the order given, each with its record and its tags resolved. This is
  # the whole answer, built in one pass so a page of twenty changes reads each class once
  # rather than once per row.
  def entries
    @entries ||= @changes.map { |change| build_entry(change) }
  end

  # One change's entry, matched by the change itself rather than by its id, so a caller
  # iterating its own rows gets the same object back. A change this reader was not built
  # with is an entry with a nil record and no tags rather than a `KeyError`: a row that
  # somehow reached a reader that does not have it is a rendering defect, and it should
  # render a row with nothing resolved rather than raise in the middle of a page.
  def entry_for(change)
    index[change] ||= build_entry(change)
  end

  private
    def index
      @index ||= entries.index_by(&:change)
    end

    def build_entry(change)
      Entry.new(change: change, record: record_for(change), tag_records: tags_for(change),
        scope_record: scope_for(change))
    end

    # Every record this draft's changes name, in one query per class. A `create` is
    # skipped here for the reason `Entry#record` states, and an unregistered
    # `record_type` is skipped because `RecordTarget.model_for` is the registry gate:
    # there is no class to ask about.
    def records
      @records ||= changes_by_type.flat_map { |type, ids| load_records(type, ids) }.index_by(&:id)
    end

    # `[]` rather than nil for a type outside the registry, so the gather above is a
    # `flat_map` over records rather than over records and nils.
    def load_records(type, ids)
      model = RecordTarget.model_for(type)
      return [] if model.nil?

      model.where(id: ids).to_a
    end

    # Grouped by type rather than by change, because that is the granularity a query
    # takes: one query answers "every Character these changes name". Ids are uniq'd so a
    # change and a second one about the same record ask for it once, and a nil id is
    # dropped because `WHERE id IS NULL` is the query a remembered create costs today.
    def changes_by_type
      @changes_by_type ||= @changes.reject { |change| change.creating? || change.record_id.blank? }
        .group_by(&:record_type)
        .transform_values { |changes| changes.filter_map(&:record_id).uniq }
    end

    def record_for(change)
      records[change.record_id] if change.record_id.present?
    end

    # Every tag the payloads name, in one query per association class — and the
    # association is derived from the payload key rather than listed, exactly as
    # `DraftsHelper#id_list_association` derives it, because the key a form submits and
    # the collection it fills have the same name in every case this application has.
    #
    # **Grouped by class, not by association name.** Eight taxonomies share one shape
    # here, and a draft that touches four of them is four queries either way; grouping by
    # the class is what makes the number "classes in this draft" rather than "keys in
    # this draft", which is the same bound for the nine taxonomies and a real saving for
    # a model's own collection writers.
    def tag_records
      @tag_records ||= requested_tag_ids.flat_map { |model, ids| load_tag_records(model, ids) }.index_by(&:id)
    end

    def load_tag_records(model, ids)
      model.where(id: ids).to_a
    end

    # `{ association class => [ids] }` across every change's payload, gathered in one
    # pass so a page of twenty changes reads the payloads once rather than once per row.
    def requested_tag_ids
      @requested_tag_ids ||= @changes.each_with_object({}) do |change, memo|
        next if change.payload.blank?

        model = RecordTarget.model_for(change.record_type)
        next if model.nil?

        change.payload.each do |name, value|
          association = tag_association(model, name)
          next if association.nil?

          ids = Array(value).compact
          next if ids.empty?

          (memo[association.klass] ||= []).concat(ids)
        end
      end.transform_values(&:uniq)
    end

    # The collection an id-list payload key fills, or nil when the key is not one,
    # delegating to the class method so the rule has one home.
    def tag_association(model, name)
      self.class.tag_association(model, name)
    end

    # **The one derivation of "which collection does this payload key fill",** so
    # `DraftPreview` can resolve a pending row's tags from the same rule this class
    # reads them by rather than a second copy that could disagree about which keys
    # are id lists at all.
    def self.tag_association(model, name)
      return unless name.to_s.end_with?("_ids")

      model.reflect_on_association(name.to_s.delete_suffix("_ids").pluralize)
    end

    # The records one change's payload named, keyed by the payload key they came from, in
    # the order the author submitted them. A key absent from the answer was not an id
    # list, which is how the caller tells "no tags" from "nothing to name".
    #
    # The submitted order is kept rather than the query's: an author's payload says
    # "Protagonist, Antagonist" and the page prints it that way, which is a fact about
    # what they asked for rather than about the order the rows came back in.
    def tags_for(change)
      return {} if change.payload.blank?

      model = RecordTarget.model_for(change.record_type)
      return {} if model.nil?

      change.payload.each_with_object({}) do |(name, value), memo|
        association = tag_association(model, name)
        next if association.nil?

        memo[name] = Array(value).filter_map { |id| tag_records[id] }
      end
    end

    # The record one change's scope column names, or nil.
    #
    # **The column is asked of the change rather than re-derived from the model**,
    # because `DraftChange#scope_attribute` is already the one place that names it —
    # the same answer `DraftMutation` used to store it and the same one
    # `DraftPreview#creates_for` compares against. Deriving it a third time here
    # would be a third copy that could disagree about which column places a record.
    #
    # **A `universe_id` scope resolves to nothing.** The page is already inside the
    # universe that column names, so the record it would return is the one thing the
    # reader can see from the address bar. Every other owner — a Story, a Scene, a
    # Section — is a record the reader cannot name from where they are, which is the
    # whole reason the column used to be dropped and the reason it is now resolved.
    def scope_for(change)
      requested = requested_scopes[change]
      return if requested.nil?

      scope_records[requested]
    end

    # `{ change => [ owner class name, scope id ] }` for every change whose payload
    # carries a scope id, gathered in one pass over payloads that are already loaded
    # with the changes.
    #
    # **Keyed by the change, not by `record_type`.** A draft routinely holds several
    # changes of the same type pointing at different stories — two Scenes under
    # different stories is the ordinary case, and it is the case the drafts page
    # exists to let a reader compare — so a per-type key has every one of them read
    # the last one's answer and name one story for all of them. The records are still
    # fetched in one query per owner class; only the keying is per change.
    #
    # **A `universe_id` scope is gathered as nothing.** The page is already inside the
    # universe that column names, so the record it would return is the one thing the
    # reader can already see from the address bar. Every other owner — a Story, a
    # Scene, a Section — is a record the reader cannot name from where they are, which
    # is the whole reason the column used to be dropped and the reason it is now
    # resolved.
    #
    # **The owner class is read from the model's own association**, which is the same
    # derivation `scope_attribute` already made, so the answer is keyed by what the
    # column names rather than by `record_type`: a `Scene`'s `story_id` names a
    # `Story`, so keying by `record_type` would look a Scene up among the Scenes.
    # A column with no association behind it is gathered as nothing rather than
    # raising, because `owner_association_for` answers from `column_names` and a
    # model can carry a scope column it never declared an owner for.
    def requested_scopes
      @requested_scopes ||= @changes.each_with_object({}) do |change, memo|
        model = RecordTarget.model_for(change.record_type)
        next if model.nil?

        association = UniverseScopeResolver.owner_association_for(model)
        owner = association && model.reflect_on_association(association)
        next if owner.nil?

        id = change.payload&.[](change.scope_attribute)
        next if id.blank?

        memo[change] = [ owner.klass.name, id ]
      end
    end

    # Every scope record this draft's changes name, in **one query per owner class**
    # across the whole draft — the same bound as the record and tag answers above, and
    # the reason a draft naming a hundred changes across five stories still costs five
    # scope queries rather than a hundred.
    def scope_records
      @scope_records ||= requested_scopes.values.uniq
                                           .flat_map { |(owner_name, id)| load_scope_records(owner_name, id) }
                                           .index_by { |record| [ record.class.name, record.id ] }
    end

    def load_scope_records(owner_name, id)
      owner_name.constantize.where(id: id).to_a
    end
end
