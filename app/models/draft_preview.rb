# What this reader's own open draft would do to the page in front of them.
#
# A draft-based universe remembers a mutation instead of writing it (ADR 0020), so
# the records a list shows and the changes a list is about to show are two
# different things. This object is the read side of that gap: it turns one open
# draft into the three answers a list page needs — what is waiting, what is
# waiting *on this record*, and what new records the draft would have created.
#
# **It reads the draft, never the content query.** A remembered create names no
# record at all (ADR 0019), so there is no row for a content query to join, and a
# remembered delete has not deleted anything yet. Merging the two would need a
# union of stored rows and unsaved ones, which is this object instead.
#
# **A pending record is an unsaved instance of the model the change names**,
# built from the columns the payload carries. That is what lets a list row render
# a remembered create with the same partials it renders a live record with, and it
# is why a pending row has no Details link, no editor, and no position: there is
# nothing to link to, and its position is the applier's to decide. Only columns
# are assigned — a submitted tag list or photo is a value the payload holds and
# the row does not, for the same reason the drafts page has to read it rather
# than print it.
#
# **Every answer is the reader's own.** The draft is looked up through
# `Draft.open_for(user, universe)`, the same lookup the remembering path and the
# editing session use, so somebody else's pending work is not an oracle here any
# more than it is on the drafts page (ADR 0021).
class DraftPreview
  # How many remembered changes the sidebar panel lists before it defers to the
  # drafts page. Each row resolves the record it names, and a long editing
  # session would otherwise put one lookup per change on **every** page of the
  # universe — the unbounded-per-row read already recorded as finding 66, widened
  # from one page to all of them.
  PANEL_LIMIT = 5

  def initialize(user:, universe:)
    @user = user
    @universe = universe
  end

  # Whether a draft can exist for this reader here at all: a signed-in reader in a
  # universe that remembers changes rather than writing them. Everything else
  # answers empty, so a `direct` universe and a guest pay nothing for asking.
  def available?
    @user.present? && @universe.present? && @universe.draft_based?
  end

  # The one open draft, or nil. There can only be one: the partial unique index
  # says so (ADR 0022), so this is a lookup rather than a search.
  def draft
    return @draft if defined?(@draft)

    @draft = available? ? Draft.open_for(@user, @universe) : nil
  end

  # Every remembered change, in the order it was remembered — the same order the
  # draft's own page uses, so the panel and the page cannot disagree about what
  # happened first.
  def changes
    @changes ||= draft ? draft.draft_changes.to_a : []
  end

  def count
    changes.size
  end

  def any?
    changes.any?
  end

  # What is waiting on one record that is still stored: `:edit` for a remembered
  # edit and `:deletion` for a remembered delete, or nil when nothing is.
  #
  # **A deletion wins an edit.** A record the author has asked to delete has a
  # row in this universe whatever else they did to it, and a row badged "pending
  # edit" above a row badged "pending deletion" would give the same record two
  # answers on the same page.
  #
  # A record is matched by its own class and id rather than by the payload, so a
  # change whose record has since been deleted simply stops being reported: it is
  # not in the list, and a badge on a record that is not on the page would be a
  # badge on nothing.
  def state_for(record)
    return if record.nil? || !record.persisted?

    states[[ record.class.name, record.id ]]
  end

  # The records the draft's remembered **creates** would have made, as unsaved
  # instances of `model`, in the order they were remembered. Keyed by model name
  # so a page asking about six lists asks the draft six times and not once per
  # record.
  def creates_for(model)
    creates.fetch(model.name) do
      creates[model.name] = changes.filter_map { |change| build(change, model) if creates?(change, model) }
    end
  end

  # The panel's slice of the changes. The full list is the drafts page; this is
  # the glance that answers "do I have something waiting?" without reading it.
  def panel_changes
    changes.first(PANEL_LIMIT)
  end

  def hidden_change_count
    [ count - panel_changes.size, 0 ].max
  end

  private
    # One pass over the changes rather than a scan per row: a list of forty rows
    # asking about forty records would otherwise be forty scans of the draft.
    def states
      @states ||= changes.each_with_object({}) do |change, memo|
        next if change.record_id.blank?

        key = [ change.record_type, change.record_id ]
        memo[key] = :deletion if change.deleting?
        memo[key] ||= :edit if change.updating?
      end
    end

    def creates
      @creates ||= {}
    end

    def creates?(change, model)
      change.creating? && change.record_type == model.name
    end

    def build(change, model)
      record = model.new
      record.assign_attributes(payload_columns(change, model))
      record
    end

    # **Only the model's own columns are assigned**, and the slice is what decides
    # it. Everything else in a payload is a collection writer (`character_tag_ids`)
    # or a virtual attribute (`photo_data`, `remove_photo`), and assigning those to
    # a record that will never be saved would build an association this object then
    # throws away. The same slice is what makes a payload describing a column that
    # has since been renamed harmless: it is dropped here rather than raising on
    # every page of the universe, and it is still readable on the draft's own page,
    # which reports what the change *says* rather than what it would make.
    def payload_columns(change, model)
      return {} if change.payload.blank?

      change.payload.slice(*model.column_names)
    end
end
