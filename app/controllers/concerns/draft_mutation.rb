# Remembers a mutation instead of writing it, in a universe whose collaboration
# mode stores changes for their author.
#
# The rule this concern carries is one sentence long: **in a draft-based universe,
# a mutation is remembered rather than written, and in a `direct` universe nothing
# here runs at all.** `Universe#draft_based?` owns the answer to "which universe is
# this", so no controller re-derives the mode from a string — and an unrecognized
# mode counts as draft-based, because a missed change is recoverable and a written
# one is not.
#
# **It is called from inside the action, not from a callback.** That is the whole
# design, and it is what keeps the concern from having to know how each controller
# builds its record. A `before_action` would have to re-read the request and
# rebuild the record to describe a change, which means answering "what would this
# action write?" twice — once for real and once for the draft — and the two answers
# drift. Here the call sits at the one point where the controller already holds both
# halves: the record it would have written and the attributes it was going to write
# with them. Each of the three methods returns `true` when it has remembered a change
# and rendered the response, and `false` — doing nothing — in a `direct` universe,
# so the caller is written as a guard and the write below it stays untouched:
#
#   def create
#     attributes = character_params
#     @character = Current.universe.characters.new(attributes)
#     return if remember_draft_create(@character, attributes)
#
#     respond_to do |format|
#       # ... the existing direct write ...
#     end
#   end
#
# **A remembered change is not validated here.** It is the author's statement of
# intent, and the applier re-runs the live mutation path — the same service, the
# same model validations — where the answer is authoritative (ADR 0019). Validating
# twice would produce two answers to one question, and the first would be taken by
# the author while the second is what actually happens. What *is* refused here is a
# change this application cannot describe: `DraftChange` owns those rules, and a
# refusal is a defect in the controller rather than something the author typed, so
# it raises instead of pretending to have remembered something.
#
# **Each controller keeps its own response flow.** The JSON workspaces answer JSON,
# because their editors submit JSON and refresh from the server afterwards; the HTML
# workspaces redirect the way their live action would. A remembered change is
# reported in the shape the caller already speaks rather than in one shape for both
# (see the response table in `docs/architecture.md`).
#
# The cost of the in-action call is stated above and paid for in the test suite: a
# controller that omits it writes straight through in a draft-based universe, so
# every mutation controller includes this concern, calls one of the three methods,
# and appears in `test/controllers/draft_mutation_test.rb` in both modes.
module DraftMutation
  extend ActiveSupport::Concern

  # Remember a record the author has not saved yet.
  #
  # `record` is the *unsaved* record the controller built — it is what says which
  # story, scene, or universe the record belongs to, which a payload of submitted
  # values alone cannot. `attributes` is what the author submitted, and it is the
  # payload, because it is the only source for the values a column does not hold:
  # tag id lists, and the two virtual photo fields, which `HasPhoto` keeps in
  # instance variables and therefore never marks as changed attributes.
  def remember_draft_create(record, attributes = {})
    return false unless draft_based_universe?

    remember_draft_change(
      action: "create",
      record: record,
      payload: draft_create_payload(record, attributes)
    )
  end

  # Remember an edit to a record that is already stored.
  #
  # `attributes` is the submitted values, as above. A controller that has *already
  # assigned* them — the Scene presence links resolve a Character, Item, or
  # Location through the universe before saving, so what they write is not what was
  # submitted — passes nothing instead, and the record's own pending changes are
  # remembered. Those are the values the live path would have written, which is the
  # only payload that can be applied without re-deciding them.
  #
  # An edit that changed nothing is still remembered: the live path would have
  # saved anyway, and a save moves the record's version.
  def remember_draft_update(record, attributes = nil)
    return false unless draft_based_universe?

    remember_draft_change(
      action: "update",
      record: record,
      payload: attributes.nil? ? draft_pending_changes(record) : draft_attributes(attributes)
    )
  end

  # Remember a delete. A delete carries no payload: it says which record and which
  # version, and nothing about the record's contents.
  def remember_draft_delete(record)
    return false unless draft_based_universe?

    remember_draft_change(action: "delete", record: record, payload: nil)
  end

  private

    # Whether this request's universe remembers changes instead of writing them.
    # `Current.universe` is present on every universe-scoped mutation, and a signed-in
    # user is too: a guest is redirected to sign in before any action runs, and a
    # draft has no owner without one.
    def draft_based_universe?
      Current.universe.present? && Current.universe.draft_based?
    end

    def remember_draft_change(action:, record:, payload:)
      change = current_draft.draft_changes.create!(
        action: action,
        record_type: record.class.name,
        # A create names no record: the id is the database's to assign when the
        # change is applied, and `DraftChange` refuses a create that names one.
        record_id: action == "create" ? nil : record.id,
        payload: payload,
        # `DraftChange.capture_base_version` is the only supported way to fill the
        # column, and this is why: a raw `updated_at` here would be stored as a
        # `Time`, and a `Time` is never equal to the string it is compared against,
        # so every remembered change would report itself a conflict.
        base_version: action == "create" ? nil : DraftChange.capture_base_version(record)
      )

      render_draft_change(change)
      true
    end

    # The draft this change joins: the author's open one in this universe, or a new
    # one. The rule is one open draft at a time, asked of the model rather than
    # enforced by a unique index, because an applied draft stays behind as history
    # and a constraint across every status would make a second editing session
    # impossible.
    #
    # Two requests that arrive together can both find no open draft and each open
    # one. That is the cost of the missing index, already accepted with the schema,
    # and the consequence is two drafts for one author rather than a rejected write.
    def current_draft
      Draft.open_for!(Current.user, Current.universe)
    end

    # The submitted attributes, as the plain string-keyed hash the payload column
    # stores. Only the top level is converted: the values are scalars and arrays of
    # scalars, which is what a form and a JSON body both produce.
    def draft_attributes(attributes)
      attributes.to_h.to_hash.transform_keys(&:to_s)
    end

    # What a create remembers: the submitted attributes plus the one column that
    # places the record in its scope. The controller built the record through the
    # association that owns it, so that column is already answered and would
    # otherwise be the one thing the payload could not say where the record goes.
    def draft_create_payload(record, attributes)
      submitted = draft_attributes(attributes)
      scope = draft_scope_attributes(record).except(*submitted.keys)

      scope.merge(submitted)
    end

    # The column that places a record in its scope, read the same way
    # `UniverseScopeResolver` walks to the same answer: the owner association it
    # walks through (`story`, `scene`, `section`), or `universe_id` for a record
    # that reaches its universe directly. Nothing else is copied out of the record,
    # because a column the author never submitted — a nil `position`, a not-yet-
    # generated `slug` — would be remembered as a value to write rather than as a
    # value to let the live path decide.
    def draft_scope_attributes(record)
      owner = UniverseScopeResolver::OWNER_ASSOCIATIONS.find do |association|
        record.class.column_names.include?("#{association}_id")
      end
      scope_attribute = owner ? "#{owner}_id" : "universe_id"

      record.attributes.slice(scope_attribute)
    end

    # The values an already-assigned record is holding but has not saved, as a flat
    # hash of the new values. This is the only payload that suits the presence
    # links, whose editors may send one field, and whose blank counterpart means
    # "keep what is stored" rather than "clear it".
    def draft_pending_changes(record)
      record.changes.transform_values(&:last)
    end

    def render_draft_change(change)
      return render json: draft_change_json(change), status: :accepted if request.format.json?

      # The HTML workspaces have no record to redirect *to* for a remembered create,
      # because nothing was written, so the author's own last page is the only place
      # that can say what happened. `redirect_back_or_to` falls back to the universe
      # itself when the request carries no usable referrer, and refuses a referrer
      # from another host. The status follows the verb, as the documented HTML flow
      # requires: a PATCH or a DELETE answers `see_other` rather than asking the
      # browser to repeat a non-GET verb as a GET.
      redirect_back_or_to(universe_path(universe_slug: Current.universe.slug),
        notice: t("drafts.flash.remembered"),
        status: draft_redirect_status)
    end

    # The verb's own status, as the documented HTML flow requires
    # (`docs/architecture.md`): a PATCH, a PUT, or a DELETE answers `see_other`
    # rather than a 302 that asks the browser to repeat the mutation as a GET
    # against the redirect target. A `create` is a POST, so its 302 is correct.
    def draft_redirect_status
      request.patch? || request.put? || request.delete? ? :see_other : :found
    end

    # The JSON body. `draft` is the one key the caller branches on, and it says
    # nothing was written; the rest identifies what was remembered, so a client can
    # point at the change without reading the draft's page first. No prose is
    # translated here: this body is read by code, and the sentence an author reads
    # belongs in the HTML flash or on the draft's own page.
    def draft_change_json(change)
      {
        draft: true,
        draft_id: change.draft_id,
        change: {
          id: change.id,
          action: change.action,
          record_type: change.record_type,
          record_id: change.record_id
        }
      }
    end
end
