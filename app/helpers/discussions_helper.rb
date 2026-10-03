module DiscussionsHelper
  # The control that opens — or starts — a record's thread, rendered in the header
  # of the record's own details page.
  #
  # Writers only, and that is the details-page contract rather than a courtesy: a
  # guest and a read-only member see the same page with no way to post. A record
  # that already has a thread gets a plain link, because the thread is a page like
  # any other and a GET is not a write; only a record with no thread gets the
  # button, which is the request that creates one.
  def discussion_control(record)
    return unless can_write_universe?
    return unless record.respond_to?(:discussion)

    if (discussion = record.discussion)
      link_to t("discussions.control.open"), universe_discussion_path(id: discussion),
        class: "btn btn-outline-secondary"
    else
      button_to t("discussions.control.start"), universe_discussions_path,
        params: { discussion: { record_type: polymorphic_type(record), record_id: record.id } },
        class: "btn btn-outline-secondary"
    end
  end

  # The word naming a record's type on the thread page, resolved through the same
  # map the search badges use so a kind is named in one place. A record with no
  # search declaration is a Scene's presence link, which is read on its Scene's
  # page and is named as the statement it is rather than as a record type.
  def record_type_label(record)
    declaration = record.class.search_declaration
    return t("discussions.show.participation_label") if declaration.nil?

    Search::Kinds.label_for(declaration.kind, declaration.taxonomy)
  end

  private

    # What `has_one as: :record` stores: the base class, so a subclass would not
    # produce a type no registry entry matches.
    def polymorphic_type(record)
      record.class.base_class.name
    end
end
