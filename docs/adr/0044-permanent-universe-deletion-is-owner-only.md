# ADR 0044: The owner may permanently delete a universe after typing its exact name

- **Status:** Accepted
- **Date:** 2026-10-29
- **Related:** [Universe access levels](0005-universe-access-levels.md), [A notification is a stored sentence](0025-a-notification-is-a-stored-sentence.md), [Universe deletion](../features/universe_deletion.md)

## Context

The application's delete is soft: `SoftDeletable#soft_delete` writes `deleted_at` and hides the
Universe and its content, which is right for a mistake somebody may want to undo. It is not a way to
erase a world. The rows, the photos, the drafts, and the histories stay, and an account that wants a
Universe gone for good has no operation that says so.

A permanent delete is a different authority from the one that hides a Universe. An administrator can
already remove it from every page and change its governance, but the content is the creator's. It is
also irreversible, so the request must prove the reader knows *which* Universe they are deleting
rather than merely that they pressed a red button.

## Decision

- **Permanent deletion is a separate action, not a change to the soft delete.** `DELETE
  /u/:universe_slug` keeps its meaning. The new operation is `DELETE /u/:universe_slug/purge`, with a
  `GET` page of the same address that explains the loss.
- **Only the owner may purge.** The action is `:purge`, answered by a new `:owner` level in
  `Ability`: `universe.owner_id == user.id`. No membership, including `admin`, produces it. The
  controller also has to override CanCan's `manage` rule with a `cannot :purge, Universe` rule,
  because `manage` otherwise expands to every action.
- **The confirmation is the exact Universe name, compared by the server.** Case, accents,
  punctuation, and whitespace are significant; a mismatch is a `422`, keeps the typed value, and
  writes nothing. The input asks the browser not to autocomplete, autocorrect, or capitalize, and a
  Stimulus controller mirrors the comparison to disable the button. The server remains the rule, so
  the operation is still refused when JavaScript or the controller is absent.
- **The purge walks the ownership graph and includes soft-deleted rows.** `UniversePurge` follows
  each declared `dependent: :destroy` and `dependent: :delete_all` association, reading
  `SoftDeletable` children through `with_deleted`, and destroys the Universe in the same
  transaction. A table list would drift; the association walk is the same graph the application's
  own cascade uses.
- **Notifications survive.** A notification is a stored sentence addressed to a reader, not a row
  owned by the Universe ([ADR 0025](0025-a-notification-is-a-stored-sentence.md)). The purge does not
  rewrite somebody else's bell.
- **The existing soft delete is not broadened.** An administrator still cannot purge, and the
  ordinary delete is still the recoverable one.

## Consequences

### Benefits

- An owner can erase a world completely, including the content a previous soft delete hid.
- The irreversible operation has its own URL, page, and confirmation: a row menu's Delete entry opens
  that page instead of acting, so the purge cannot be reached in one click.
- Administrators keep every governance power they had without gaining the creator's erase.

### Costs and constraints

- The purge is a table walk in Ruby, not a database cascade. It is slower than a single `DELETE`, and
  a future Universe-owned model must declare its cascade or it will not be reached.
- Soft-deleted rows are deliberately destroyed, so there is no recovery path for a mistaken purge.
- The typed-name check is literal: a Universe whose name is awkward to type is awkward to delete.

## Alternatives considered

### Alternative: Make the existing delete permanent

It would remove the recoverable operation the rest of the application uses, and a mis-click on a
row menu would become unrecoverable. The two operations answer different intents.

### Alternative: Ask administrators, not only the owner

An administrator can already hide a Universe, but not erase the work of the person who founded it.
The owner is the one authority every Universe has without a membership row.

### Alternative: A checkbox or a confirm dialog

Both are one gesture. The name is the part that makes the reader read which Universe is in front of
them, which is the reason a repository deletion asks for the repository name.

## Related documentation

- [`../features/universe_deletion.md`](../features/universe_deletion.md)
- [`../data_model.md`](../data_model.md)
- [`../architecture.md`](../architecture.md)
