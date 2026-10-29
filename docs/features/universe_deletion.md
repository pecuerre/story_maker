# Universe deletion

A Universe has two deletes, and they are deliberately different operations.

| Action | Who | What happens | Reversible |
|---|---|---|---|
| **Delete universe** (`DELETE /u/:universe_slug`) | an owner or an administrator | `SoftDeletable#soft_delete` marks the Universe and its content with `deleted_at` | yes, the rows remain |
| **Permanent delete** (`DELETE /u/:universe_slug/purge`) | **the owner only** | `UniversePurge` destroys the Universe and every row it owns, including soft-deleted rows | no |

The ordinary delete is the route behind `SoftDeletable`; it is not offered in the Universe action menus
any more, because a one-click menu entry was how a permanent-looking delete could hide a Universe
without the confirmation. The permanent delete lives on `/u/:universe_slug/purge`, reached from the
**Delete universe permanently** entry in the Universe action menus and the same control in the edit
page's danger zone.

## Who may do it

The permanent delete asks for the `:purge` action on the Universe, which `Ability` answers from its
`:owner` level: `universe.owner_id == user.id`. It is **not** an `:admin` action. An administrator
may soft-delete a Universe, manage its members, and change its settings, but cannot erase the
creator's work; the request answers `403`. A guest is sent to sign in from a public Universe, and a
signed-in non-member of a private Universe receives the same `404` as a missing Universe.

`UniverseAuthorization` names this controller's whole action surface, so the page and the write
cannot disagree about who may use them.

## The typed-name confirmation

The page shows what will be lost and requires the reader to type the Universe's name. The comparison
is on the server, in `UniversePurgesController`, and it is a literal string comparison against the
record the request already authorized:

- every capital letter, accent, comma, apostrophe, and space must match;
- leading or trailing whitespace is a different value;
- a blank confirmation deletes nothing.

A mismatch re-renders the page with `422` and a message naming the Universe, keeps what the reader
typed in the field, and writes nothing. The exact comparison is the rule; there is no case folding,
trimming, or Unicode normalization anywhere on the path.

The browser is asked not to help. The form and the input carry `autocomplete="off"`, and the input
also carries `autocapitalize="none"`, `autocorrect="off"`, and `spellcheck="false"`. The
`name-confirmation` Stimulus controller keeps the destructive submit button disabled until the value
matches, and the button is rendered disabled, so it never starts out enabled. **The controller is not
the authorization or the rule**: the server compares the value again, so a request that bypasses the
button — a direct `DELETE`, a stale page, an edited form — is still refused unless the name matches
exactly.

## What is destroyed

`UniversePurge` walks the Universe's declared `dependent: :destroy` and `dependent: :delete_all`
associations, destroys every child, then destroys the Universe itself — all in one transaction. A
raise rolls the transaction back rather than leaving half a Universe behind.

Two details make the walk complete:

- **Soft-deleted rows are included.** A `dependent: :destroy` association reads its model's default
  scope, so a Story, Character, or Scene that was soft-deleted earlier is invisible to Active
  Record's cascade. The purge reads each child relation through `with_deleted` when its model is
  `SoftDeletable`, so hidden rows go too.
- **Association declarations, not a table list.** A new Universe-owned model that declares its
  cascade arrives in the purge with it. `dependent: :nullify` associations are deliberately not
  followed, and HABTM join rows are removed by Active Record when either endpoint is destroyed.

That covers the Universe Bible records (Characters, Factions, Faction relationships, Locations,
Routes, Canon rules, Items, Events, Relations, Ownerships, the nine tag taxonomies), every Story and
its Sections, Plots, Scenes, Scene Elements, dialogue turns, presence and Event links, and Story/Scene
trope annotations; every Draft, remembered change, apply outcome, review request, and Discussion
message; memberships; API token Universe links; Photos, whose Active Storage attachments purge their
stored files; and every record that was already soft-deleted. Then the Universe row itself.

Search documents are removed by the destroyed records' own `Searchable` callbacks, and the cached
menu and summary counts for the Universe are expired.

## What survives

- **Notifications.** A notification is a stored sentence with no foreign key to its subject
  ([ADR 0025](../adr/0025-a-notification-is-a-stored-sentence.md)); it is addressed to a reader, not
  owned by the Universe, and it stays in their bell.
- **Accounts, sessions, and API tokens.** The Universe is deleted; the people and their credentials
  are not. Destroying an API token's Universe link does not revoke the token itself.
- **Other Universes.** The purge reaches only rows inside the authorized Universe; a Story in
  another Universe keeps its records.

## Verification

- `test/models/universe_purge_test.rb` walks every Universe-, Story-, Scene-, Discussion-, and
  Draft-scoped table and every HABTM join table after a purge, with content soft-deleted first.
- `test/controllers/universe_purges_controller_test.rb` covers the owner, an administrator, a
  non-member, a guest, the exact-name comparison, and the danger-zone link.
- `test/javascript/name_confirmation_controller_test.js` and `test/system/universes_test.rb` cover
  the browser half: no autocomplete, and a button that only enables on the exact name.
