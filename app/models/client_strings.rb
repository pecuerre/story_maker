# The strings a Stimulus controller reads, and the one place that decides which.
#
# A client-side string is not a `t()` call: the browser has no I18n backend, and
# ADR 0016 settled the boundary as "the server resolves it, the browser prints
# it". This module is the server half of that boundary. It owns the exact list
# of keys the shipped controllers read, resolves them for the request being
# rendered, and serializes them into the one JSON blob the layout renders.
#
# Why the list lives here rather than in a view: a key a controller reads but no
# view sends is a key the reader sees in English, and a view that sends a key no
# controller reads is a translation nobody can reach. Both are silent failures in
# a language the suite never runs in. Owning the list in one Ruby constant lets
# `ClientStringsTest` say something about both directions, and it makes a new
# client string a decision recorded in a file a reviewer reads rather than a
# string literal buried in a controller.
#
# **A key is resolved per request, never in a frozen constant.** `payload` calls
# `I18n.t` against `I18n.locale` at render time, for the same reason
# `TagsHelper#tag_workspace_base` resolves `UNIVERSE_TAG_METADATA`'s keys per
# request: a constant that called `t()` would be resolved once, in whatever
# locale happened to load the class first, and every later request would render
# that one language.
#
# **A record's own words are never in here.** Names, descriptions, and tag names
# are the author's data; the server already sends them where a controller needs
# them (`item.title`, `node.dataset.name`), and they are not chrome.
#
# The client half is `app/javascript/i18n.js`, which every controller imports.
# Nothing here is asked of a controller twice: a string it reads, a noun it
# cannot derive, and a plural it does not choose.

module ClientStrings
  # The keys the taxonomy tree's controller reads.
  #
  # `shared.form.*` and `shared.taxonomy_node.rename` are keys the server
  # already renders, and the client reuses them rather than keeping a second
  # copy: a reader who clicks **Rename** in a rendered row and then cancels an
  # inline rename in the same language has read one word twice and expects it to
  # be one word.
  #
  # `shared.record_error`, `shared.record_message`, and the two
  # `shared.modal_form.*` sentences a rejected editor save reports are shared with
  # the flat-list editor, so a refused save reads the same whichever editor
  # refused it — which is the same one-home rule that keeps "Cancel" one word
  # across the two editors.
  TAXONOMY_TREE = %w[
    shared.form.cancel
    shared.form.close
    shared.record_error
    shared.record_message
    shared.taxonomy_node.rename
    shared.taxonomy_tree.edit_title
    shared.taxonomy_tree.new_name
    shared.taxonomy_tree.save
    shared.taxonomy_tree.save_changes
    shared.taxonomy_tree.required
    shared.taxonomy_tree.delete_confirm
    shared.taxonomy_tree.insert_at
    shared.taxonomy_tree.record_subject
    shared.taxonomy_tree.create_failed
    shared.taxonomy_tree.rename_failed
    shared.taxonomy_tree.update_failed
    shared.taxonomy_tree.delete_failed
    shared.taxonomy_tree.move_failed
    shared.taxonomy_tree.network_failed
    shared.taxonomy_tree.invalid_response
    shared.taxonomy_tree.saved_refresh
    shared.modal_form.unexplained
    shared.modal_form.fix_and_retry
    modal_fields.photo
  ].freeze

  # The keys the photo editor's controller reads. Every one of the three page
  # patterns reaches it — the JSON modals, the taxonomy editor's JavaScript-built
  # modal, and the plain full-page forms — so this is one list rather than three.
  PHOTO_CROP = %w[
    shared.form.cancel
    shared.photo_field.hint
    shared.photo_field.remove
    shared.photo_field.stage_aria
    shared.photo_field.zoom
    shared.photo_field.zoom_aria
    shared.photo_field.accept
    shared.photo_field.move_group_aria
    shared.photo_field.move_left
    shared.photo_field.move_up
    shared.photo_field.move_down
    shared.photo_field.move_right
    shared.photo_field.reading
    shared.photo_field.unreadable
    shared.photo_field.ready
    shared.photo_field.chosen
    shared.photo_field.discarded
    shared.photo_field.removing
  ].freeze

  # The keys the flat-list modal's controller reads. Its own Cancel button is
  # server-rendered, so `shared.form.cancel` is not among them.
  MODAL_FORM = %w[
    shared.record_error
    shared.record_message
    shared.modal_form.saving
    shared.modal_form.saved_refresh
    shared.modal_form.save_failed
    shared.modal_form.unsent
    shared.modal_form.deleting
    shared.modal_form.deleted_refresh
    shared.modal_form.delete_failed
    shared.modal_form.delete_unsent
    shared.modal_form.gone_refresh
    shared.modal_form.moving_up
    shared.modal_form.moving_down
    shared.modal_form.moved_refresh
    shared.modal_form.move_failed
    shared.modal_form.move_unsent
    shared.modal_form.gone_row_refresh
    shared.modal_form.unexplained
    shared.modal_form.fix_and_retry
    shared.modal_form.forbidden
    shared.modal_form.rejected
    shared.modal_form.server_error
    shared.modal_form.http_status
  ].freeze

  # The keys the top-bar search's controller reads.
  #
  # `searches.commands_title` is the results page's own heading for the same
  # group, and the dropdown's group label is that word rather than a second one:
  # the two surfaces show the same list.
  SEARCH = %w[
    searches.commands_title
    searches.bar.type_more
    searches.bar.no_matches
    searches.bar.no_matches_announce
    searches.bar.matches_announce
    searches.bar.unavailable
    searches.bar.unreachable
    searches.bar.unavailable_reason
    searches.bar.results_group
    searches.bar.result_label
  ].freeze

  # Every key any shipped controller reads, deduplicated and sorted so a diff is
  # a diff of the set rather than of the order four lists happen to be in.
  KEYS = (TAXONOMY_TREE + PHOTO_CROP + MODAL_FORM + SEARCH).uniq.sort.freeze

  # The record types whose `base` error the flat-list modal reads as a sentence.
  #
  # `modal_form_controller.js` composes a record-level message as "the <record>
  # <message>", and the noun it holds is the model's own `model_param` — a
  # **value**, because the same string names the form field the controller posts
  # (`scene_element[name]`). The client cannot turn that value into a noun, so it
  # asks: the server answers with the reader's own words for that record type.
  #
  # The list is the `data-modal-form-model-param-value` each workspace declares,
  # and `ClientStringsTest` reads that declaration out of the views rather than
  # repeating it here, so a new workspace fails the suite instead of falling back
  # to a humanized English parameter in a Spanish page.
  #
  # A Spanish subject carries the determiner the English sentence supplies itself
  # ("the event" / "este suceso"), for the reason
  # `shared.error_summary.heading` gives: a bare noun in that slot needs an
  # article the sentence's own wording cannot know.
  RECORD_SUBJECTS = %w[
    character
    event
    item
    ownership
    relation
    scene_character
    scene_element
    scene_item
    scene_location
  ].freeze

  class << self
    # The blob the layout renders, as a JSON string.
    #
    # Flat, keyed by the full dotted key, because the client resolves a key it
    # was given rather than one it assembled: `t("shared.form.cancel")` is
    # greppable from a controller straight to its locale entry, and a nested blob
    # would make the client walk a path to get there.
    #
    # A pluralized key is resolved with `resolve: false`, so the entry travels as
    # its whole `{ one:, other: }` hash rather than one form chosen here. The blob
    # is rendered once per page while the count is only known when a controller
    # asks, so choosing the form is necessarily the client's job — and it is a
    # *mechanical* one: `app/javascript/i18n.js` picks the form with
    # `Intl.PluralRules` for the locale named here, which is the platform's own
    # rule table rather than a `count === 1` written into a controller. The words
    # are still the locale file's; only the choice among them moved.
    #
    # `locale` travels with the strings for the same reason: a page whose blob
    # and whose `<html lang>` disagreed would pick a plural rule that does not
    # match the words it is choosing between.
    #
    # The whole set is sent on every page rather than per controller, because
    # which controllers a page carries is not something the layout can know
    # (`photo_crop` appears inside the taxonomy tree's JavaScript-built modal,
    # which is not in the DOM yet when the layout renders), and a key that
    # arrives late is a key that arrives in the wrong language. The blob is a few
    # hundred words of chrome; correctness is worth more than the bytes.
    def payload
      strings = KEYS.index_with { |key| I18n.t(key, resolve: false) }
      strings[:locale] = I18n.locale.to_s
      strings[:record_subject] = RECORD_SUBJECTS.index_with { |param| subject_for(param) }
      strings.to_json
    end

    # The reader's own noun for a record type, for a message that reads as a
    # sentence about it.
    #
    # `count: 1` is what makes the root noun singular — "the element", not "the
    # elements". The `default` is a last resort for a `model_param` the list does
    # not carry; `ClientStringsTest` fails the suite in that case rather than
    # letting the fallback reach a reader.
    def subject_for(model_param)
      I18n.t("record_subject.#{model_param}", count: 1, default: model_param.to_s.humanize.downcase)
    end
  end
end
