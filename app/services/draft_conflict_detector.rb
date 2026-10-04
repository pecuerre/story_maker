# Answers, for every change in one draft, whether it can still be written — and
# says which record it is about and what state that record is in now.
#
# **The rule.** A change that names a record was remembered against one version of
# it, stored in `base_version` through `VersionStamp`. At apply time the record is
# read again and the two versions are compared:
#
#   * **Create** — names no record, so there is nothing that could have moved. A
#     remembered create cannot conflict, and it is not this detector's business
#     whether it can be *placed*: that is the applier's own `:unplaceable` answer,
#     about a stored scope column rather than about a version.
#   * **Update** — the record has moved (`:moved`) or somebody has deleted it
#     (`:deleted`). Either way the remembered values were written against a record
#     that is no longer the one the author saw.
#   * **Delete** — the record has moved (`:moved`) is a conflict. A record that is
#     *already* soft-deleted (`:gone`) is **not**: the author's intent is already
#     true, so there is nothing to decide and nothing to overwrite.
#   * **No row at all, or a row in another universe** (`:missing`) — not a
#     conflict either. There is no record to have moved, and reporting a conflict
#     the author cannot act on is the same noise this class exists to remove.
#
# **Deletion is asked before the version, deliberately, and the order is what
# makes both delete rows correct.** `soft_delete` writes `deleted_at` *and* moves
# `updated_at`, so a record somebody else has deleted satisfies "the version
# changed" as well — asking the version first would report every already-deleted
# record as a conflict and make the `:gone` row unreachable. The cost of the
# order is that an update onto a deleted record is reported as `:deleted` rather
# than `:moved`, which is the more useful of the two answers: it says the record
# is gone, not merely that something about it differs.
#
# **A missing base counts as moved.** `VersionStamp.changed?` compares as strings
# and treats a `nil` base as unequal, so the conservative direction is inherited
# rather than re-decided here: a conflict an author can see and answer is
# recoverable, a silently overwritten edit is not.
#
# **This is the only reader of the "has it moved" question.** `DraftApplier` asks
# this detector rather than repeating the comparison, so the apply's skip decision
# and the resolution page's list of conflicts cannot disagree about which changes
# are in conflict. It is deliberately *not* called from a list workspace or from
# the sidebar's pending panel: resolving a record per change is a query per row
# (known quirk 66), and a page that renders on every request of a universe cannot
# pay that. Detection belongs at apply time, where the number of rows is one
# draft and the author is about to act on the answer.
#
# A corrupt row is reported, not raised. An unregistered `record_type` or an id
# naming nothing is `:missing` here, where the detector can say so; the applier
# still raises when a **create** needs a class it does not have, because that one
# has no answer to report (ADR 0021).
class DraftConflictDetector
  # The two states that are a conflict rather than an answer, named once so that
  # `DraftApplier`'s skip reason and a resolution page's listing are one vocabulary
  # and not two lists that have to be kept in step.
  CONFLICT_REASONS = %i[moved deleted].freeze

  # One change's standing at apply time.
  #
  # `state` is one of:
  #
  #   * `:writable` — no conflict; `record` is the live record to write, or nil for
  #     a create, which names none.
  #   * `:moved` — the record's version is no longer the one this change was
  #     remembered against.
  #   * `:deleted` — somebody has soft-deleted the record, so an update onto it has
  #     nothing to write and the author has to choose between restoring it and
  #     letting it go.
  #   * `:gone` — a delete whose record is already soft-deleted. Not a conflict: the
  #     author's intent already holds, so there is nothing to resolve.
  #   * `:missing` — no row, a row outside the draft's universe, or a type outside
  #     the content registry.
  #
  # `record` is carried even when the change is not writable, because a resolution
  # page has to show the record's **current** state to answer "theirs" against —
  # that record is the "theirs" half, read now rather than remembered then.
  Report = Data.define(:change, :state, :record) do
    # Whether this change can be written as it stands.
    def writable?
      state == :writable
    end

    # Whether the author has to choose between their remembered values and the
    # record's current ones. `:gone` and `:missing` are answers rather than
    # choices, which is why they are not conflicts.
    def conflict?
      DraftConflictDetector::CONFLICT_REASONS.include?(state)
    end

    # The reason this change is in conflict, or nil when it is not. This is also
    # the reason `DraftApplier` reports it under, so a skipped change's reason and
    # a conflict's reason are one vocabulary.
    def conflict_reason
      state if conflict?
    end
  end

  def initialize(draft)
    @draft = draft
  end

  # Every change in the draft, in the order they were remembered, with its state.
  # This is the whole answer in one pass; `report_for` is the same question asked
  # about one change.
  def reports
    @draft.draft_changes.map { |change| report_for(change) }
  end

  # One change's state, read now and not remembered: a record deleted after the
  # report was built must stop resolving, and the applier calls this per change
  # inside its own transaction.
  def report_for(change)
    return Report.new(change, :writable, nil) if change.creating?

    record = record_for(change)
    return Report.new(change, :missing, nil) if record.nil?

    if RecordTarget.soft_deleted?(record)
      return Report.new(change, change.deleting? ? :gone : :deleted, record)
    end

    Report.new(change, moved?(change, record) ? :moved : :writable, record)
  end

  # The changes that are in conflict, in the order they were remembered. What a
  # resolution page lists.
  def conflicts
    reports.select(&:conflict?)
  end

  # One change's conflict, or nil when it is not in conflict.
  def conflict_for(change)
    report = report_for(change)

    report if report.conflict?
  end

  private
    # The record a change names, read the one way a polymorphic reference is read
    # anywhere in this application: through the content registry, and required to
    # belong to the draft's own universe. Both refusals are one answer, because
    # from here they are the same thing — there is no record to write.
    #
    # `find_including_deleted` rather than `find`, so a soft-deleted record
    # resolves and can be reported as deleted instead of vanishing into the same
    # answer as an unknown id. The universe check is not folded into it because the
    # registry gate is what makes the constant safe to load, and the scope check is
    # what makes the row this draft's to write.
    def record_for(change)
      record = RecordTarget.find_including_deleted(record_type: change.record_type, record_id: change.record_id)
      return if record.nil?
      return unless RecordTarget.owned_by?(record, @draft.universe)

      record
    end

    # Whether the record has moved since the change was remembered against it. A
    # `create` is asked this question nowhere: it names no record, so there is
    # nothing that could have moved.
    def moved?(change, record)
      VersionStamp.changed?(record, change.base_version)
    end
end
