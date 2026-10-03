# Reading a remembered change on a draft's own page.
#
# A change is the author's *statement of intent*, and this page's whole job is to
# say what that statement is: which record it is about, what it would do to it,
# and what values it carries. It deliberately does not say whether the change was
# written. Only the apply that wrote it can know that, and a page that inferred it
# from a version stamp would be reporting a second answer about the same record.
#
# Three shapes need reading rather than printing:
#
# * **A record type** is named with the same word a search result badge uses
#   (`Search::Kinds`), so a Character is called a character here and in the
#   dropdown. Three content models are not search documents at all — a Scene's
#   three presence links — and `searches.kinds` deliberately does not name them,
#   so `drafts.kinds` names exactly those three.
# * **A submitted id list** — a tag assignment, or a Dialogue's speakers — is ids,
#   which means nothing to a reader. Every one of them is a collection writer on
#   the model, so the names are one association hop from the key the form sent
#   (`character_tag_ids` → `character_tags`, `character_ids` → `characters`), and
#   the row can print what the change is actually about. It is labelled by that
#   association as well, because "Character tags" is the word the editor sees
#   everywhere else and `character_tag_ids` is a name nobody uses.
# * **A photo** is stored as a `data:` URL and removed by a boolean. Printing
#   either would put a base64 blob or a bare `0` on the page, so both are stated.
module DraftsHelper
  # What a change's row calls itself: the record's own label when the change names
  # one that is still there, and the type it would create when it does not.
  #
  # `record` is passed in rather than resolved here because the row needs the same
  # answer twice — to decide whether to link and to write the link — and
  # `DraftChange#resolved_record` deliberately does not remember its answer, so a
  # second call would be a second query and could disagree if the record changed
  # between them.
  def draft_change_subject(change, record)
    return t("drafts.show.new_record", kind: draft_change_kind(change)) if record.nil?

    record_label(record)
  end

  # The word for the record type a change names, whether or not the record is
  # still there: a change about a record somebody else has since deleted still
  # has to say what it was about.
  def draft_change_kind(change)
    model = RecordTarget.model_for(change.record_type)
    return t("drafts.kinds.unknown") if model.nil?

    declaration = model.searchable? ? model.search_declaration : nil
    return t("drafts.kinds.#{model.model_name.param}") if declaration.nil?

    Search::Kinds.label_for(declaration.kind, declaration.taxonomy)
  end

  # The remembered attributes, as `[ label, value ]` pairs, in the order the
  # payload stores them.
  #
  # The scope column is dropped: it is the column that placed the record in its
  # universe, story, or scene, and this page is already inside that universe — a
  # bare `story_id` is a number the reader cannot name. Everything else is kept,
  # including the values a column does not hold, because a tag list or a photo is
  # the part of the change that `record.changes` would have dropped.
  def draft_change_attributes(change)
    return [] if change.payload.blank?

    model = RecordTarget.model_for(change.record_type)

    change.payload.filter_map do |name, value|
      next if name == change.scope_attribute

      association = id_list_association(model, name)
      [ draft_change_label(model, name, association), draft_change_value(model, name, value, association) ]
    end
  end

  private
    # The attribute's own name, resolved the way every form label and every
    # `errors.format` sentence in this application resolves it. A column the
    # locale has not named falls back to a humanized English name, which is the
    # documented behaviour of `human_attribute_name` rather than a second
    # vocabulary kept here.
    #
    # A submitted id list is labelled by the collection it fills rather than by the
    # writer that submitted it: the editor sees "Character tags" everywhere else
    # and has no idea what a `character_tag_ids` is, and the association is the
    # same word the field's own name already is minus the `_ids`.
    def draft_change_label(model, name, association)
      field = association ? association.name : name

      model&.human_attribute_name(field) || field.humanize
    end

    # One remembered value, as the reader should see it. `nil` never reaches the
    # page as a blank cell, because a blank value is a state worth naming and
    # `shared.detail_fact.blank` is this application's one answer to it.
    def draft_change_value(model, name, value, association)
      return association_names(association, value) if association.present?
      return t("drafts.attributes.photo") if name == "photo_data"
      return t("drafts.attributes.photo_removed") if name == "remove_photo" && truthy?(value)
      return value.to_sentence if value.is_a?(Array)

      value.presence || t("shared.detail_fact.blank")
    end

    # A submitted id list the model has a collection for: a tag assignment, or a
    # Dialogue's speakers. The association is derived from the key rather than
    # listed, because the key a form submits and the collection it fills have the
    # same name in every case this application has.
    def id_list_association(model, name)
      return if model.blank? || !name.end_with?("_ids")

      model.reflect_on_association(name.delete_suffix("_ids").pluralize)
    end

    # The names behind the ids, in the order the author submitted them, joined in
    # the reader's language — `to_sentence` reads `support.array`, which both
    # locale files carry. An id that no longer resolves is dropped rather than
    # printed: it names nothing, and the change it was part of is the author's
    # statement about the ids that are still there.
    def association_names(association, value)
      names = Array(value).filter_map { |id| association.klass.find_by(id: id) }.map { |record| record_label(record) }

      names.to_sentence.presence || t("shared.detail_fact.blank")
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value).present?
    end
end
