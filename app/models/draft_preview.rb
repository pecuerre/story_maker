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
# nothing to link to, and its position is the applier's to decide.
#
# **Its tags are resolved and assigned; its photo is held beside it.** Both are
# values no column carries, and both used to be dropped here — which made a
# remembered create show *less* than the author submitted, on the one surface that
# exists to tell them their create is waiting. The tag list is the case that
# matters most, because a live row in the same list does print its tag badges:
# assigning the resolved `CharacterTag` records onto the unsaved record's
# association is free (`DraftChanges::Reader` reads them in one query per tag
# class for the whole draft, and reading an assigned association back off a new
# record asks the database nothing), and it means a pending row goes through the
# same `entity_tag_badge` ladder a live row does rather than a second rendering
# path. The photo cannot be assigned — `photo_data=` marks the value as submitted,
# so a record that was ever validated would try to decode and store an image for a
# row that will never be saved — so it is read through `#photo_for` instead.
#
# **What a badge may say beyond its state is bounded here, once.** A row badged
# "pending edit" is a claim the reader has to take on trust, because the row
# underneath it still shows the stored values; the one thing that makes the claim
# checkable is naming what the draft would write. So a stored record's answer is
# a `Pending` — the state, how many remembered changes name it, and the payload
# keys those changes carry — and it is built in the **same single pass** as the
# state, because `changes` already holds every payload and a second pass would
# buy nothing. A remembered **delete carries no payload** (`DraftMutation` says so
# deliberately), so a deletion can report a count and never a field.
#
# **Every answer is the reader's own.** The draft is looked up through
# `Draft.open_for(user, universe)`, the same lookup the remembering path and the
# editing session use, so somebody else's pending work is not an oracle here any
# more than it is on the drafts page (ADR 0021).
class DraftPreview
  # What is waiting on one stored record, as the three facts a badge and its
  # tooltip both read: which state wins, how many remembered changes name the
  # record, and which payload keys those changes carry.
  #
  # **The keys are the payload's own, not words.** A change says `name` and
  # `character_tag_ids`, and what a reader calls them is the view layer's
  # business — the same rule `DraftChanges::Reader` holds records rather than
  # labels under. So this holds what would be written and `DraftsHelper` names it.
  #
  # `attribute_names` is the union across the record's changes in the order the
  # author first submitted them, deduplicated: two remembered edits to the same
  # column are one field, and a reader asking "which fields would this write"
  # wants the answer once.
  Pending = Data.define(:state, :count, :attribute_names) do
    def edit?
      state == :edit
    end
  end

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

  # What is waiting on one record that is still stored, or nil when nothing is.
  #
  # This is the whole per-row answer, and it is one hash lookup: the state a badge
  # shows, how many remembered changes name the record, and which payload keys
  # they carry. Asking for the three separately would mean three passes over the
  # draft, and a list of forty rows asking about forty records is exactly the
  # shape the single pass below exists for.
  #
  # A record is matched by its own class and id rather than by the payload, so a
  # change whose record has since been deleted simply stops being reported: it is
  # not in the list, and a badge on a record that is not on the page would be a
  # badge on nothing.
  def pending_for(record)
    return if record.nil? || !record.persisted?

    pendings[[ record.class.name, record.id ]]
  end

  # The state alone, for a caller that has no use for the rest — `DraftsHelper`
  # derives the badge's word from it and reaches for `pending_for` when it also
  # has to say what the change would write.
  def state_for(record)
    pending_for(record)&.state
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

  # The photo a remembered create carries, as a `data:` URL, or nil when the
  # payload submitted none.
  #
  # **Read through the change rather than assigned to the record**, because
  # `HasPhoto#photo_data=` also marks the value as *submitted*, and the work that
  # flag turns on — decoding the data URL, re-encoding it to a square, writing a
  # `Photo` row — belongs to a save. A pending row is never saved, so assigning it
  # would buy a thumbnail and risk an image pipeline running for a record that does
  # not exist. The tag list has no such flag, which is why `#build` can assign that
  # one and not this.
  #
  # **The value is not an image until it is checked, and this does not check it.**
  # `photo_data` is whatever reached the controller, stored verbatim; a payload
  # naming a renamed column is dropped and harmless, and a payload whose photo is
  # not a decodable image is refused by the applier when the change runs. A view
  # that wants to put this in an `img src` gates it on `PhotoProcessing::DATA_URL`
  # first — see `DraftsHelper#draft_pending_photo`.
  def photo_for(record)
    submitted_photos[record]
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
    #
    # **A deletion wins an edit.** A record the author has asked to delete has a
    # row in this universe whatever else they did to it, and a row badged "pending
    # edit" above a row badged "pending deletion" would give the same record two
    # answers on the same page. The count and the fields are still accumulated,
    # because they are facts about the draft rather than about the badge: a
    # record with one edit and one delete has two remembered changes on it, and
    # the delete's payload is empty rather than absent — so the fields are read
    # from the changes that carry one.
    def pendings
      @pendings ||= changes.each_with_object({}) do |change, memo|
        next if change.record_id.blank?

        key = [ change.record_type, change.record_id ]
        memo[key] = accumulate(memo[key], change)
      end
    end

    def accumulate(pending, change)
      attributes = pending.nil? ? payload_attribute_names(change) : pending.attribute_names | payload_attribute_names(change)

      Pending.new(
        state: change.deleting? ? :deletion : (pending&.state || :edit),
        count: pending.nil? ? 1 : pending.count + 1,
        attribute_names: attributes
      )
    end

    # The payload keys one change would write, minus the column that places the
    # record in its scope.
    #
    # **The scope column is dropped here for the reason the drafts page drops it
    # too**: it says *where* the record goes rather than *what would change about
    # it*, and a bare `story_id` is a number a reader cannot name. It is asked of
    # the change rather than re-derived from the model, because
    # `DraftChange#scope_attribute` is already the one place that names it.
    #
    # The keys are **not** filtered to what the model can answer, because a field
    # the payload names and the model does not have is still something the draft
    # would try to write — the applier is what refuses it. `DraftsHelper` is where
    # the naming happens, and it is the layer that decides what a reader can be
    # shown.
    def payload_attribute_names(change)
      return [] if change.payload.blank?

      change.payload.keys.reject { |name| name == change.scope_attribute }
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
      assign_submitted_tags(change, model, record)
      remember_submitted_photo(change, record)
      record
    end

    # **Only the model's own columns are assigned**, and the slice is what decides
    # it. Everything else in a payload is a collection writer (`character_tag_ids`)
    # or a virtual attribute (`photo_data`, `remove_photo`). The slice is what
    # makes a payload describing a column that has since been renamed harmless: it
    # is dropped here rather than raising on every page of the universe, and it is
    # still readable on the draft's own page, which reports what the change *says*
    # rather than what it would make.
    def payload_columns(change, model)
      return {} if change.payload.blank?

      change.payload.slice(*model.column_names)
    end

    # The tags the author submitted, assigned onto the record's own association so
    # `entity_tag_badge` reads them exactly as it reads a stored row's.
    #
    # **Assigning resolved records rather than ids is what makes this free.** An id
    # writer on a new record leaves the association unloaded, so the badge that reads
    # it would issue one query per pending row — the per-row read this class exists
    # to avoid. Assigning the records themselves loads the association outright, and
    # no join row is written because a pending record is never saved. The ids are
    # read through `DraftChanges::Reader`, which resolves a whole draft's payloads in
    # one query per tag class, so a list of pending rows costs one query for the
    # draft rather than one per row.
    #
    # A tag the author named that has since been deleted is dropped rather than
    # printed, which is the reader's own rule for a remembered tag list.
    def assign_submitted_tags(change, model, record)
      submitted_tags_for(change, model).each do |association, tags|
        record.public_send(:"#{association.name}=", tags)
      end
    end

    # The id-list keys in this payload that the model actually has a collection for,
    # each with the tags that key named — already resolved, and keyed by the payload
    # key the reader answers by, so this is the same derivation and the same lookup
    # rather than a second one.
    def submitted_tags_for(change, model)
      return [] if change.payload.blank?

      change.payload.filter_map do |name, _ids|
        association = DraftChanges::Reader.tag_association(model, name)
        next if association.blank?

        [ association, reader.entry_for(change).tags_for(name) ]
      end
    end

    def reader
      @reader ||= DraftChanges::Reader.new(changes)
    end

    # The photo a pending record was given, held beside the record rather than on it.
    # Keyed by object identity because a pending record is an unsaved instance and
    # two of them for different changes compare equal by class alone.
    def remember_submitted_photo(change, record)
      data_url = change.payload&.[]("photo_data")
      submitted_photos[record] = data_url if data_url.present?

      record
    end

    def submitted_photos
      @submitted_photos ||= {}.compare_by_identity
    end
end
