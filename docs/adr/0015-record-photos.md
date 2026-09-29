# ADR 0015: Give every main record one optional Photo, stored only as a finished 300×300 square

- **Status:** Accepted
- **Date:** 2026-09-29
- **Related:** [`../architecture.md`](../architecture.md),
  [`../data_model.md`](../data_model.md),
  [`../conventions.md`](../conventions.md),
  [`../development.md`](../development.md),
  [0001](0001-universe-and-story-scope.md),
  [0002](0002-json-crud-with-stimulus-editors.md),
  [0011](0011-modal-json-mutation-contract.md),
  [0012](0012-client-side-verification-and-csrf.md)

## Context

A story universe's records are text today: a character is a name, a description, and some tags. The
owner asked for one optional photo on every "main" model and tag — universes, stories, sections,
scenes, characters, locations, items, events, relations, ownerships, and all eight tag models — with
four requirements that do not agree with each other by accident:

- **Optional, everywhere, always.** A record with no photo is a normal record. Nothing may make a
  photo required, and no page, list, or form may assume one exists.
- **A photo is a square.** A source image is usually not square, so the author chooses the square.
- **The stored file is 300×300, and the original is never kept.** The original is the largest,
  heaviest, and most privacy-bearing thing in the request: a camera photo carries GPS coordinates, a
  device serial, and a timestamp.
- **It has to appear in three different editors.** This application has exactly three page patterns
  ([ADR 0002](0002-json-crud-with-stimulus-editors.md)): a JSON modal over a flat list, a
  DOM-built modal in the taxonomy tree, and a plain Turbo full-page form. Each has its own
  submission contract, and they are not compatible with a `multipart/form-data` body: the JSON
  modals post `application/x-www-form-urlencoded` and the taxonomy modal is assembled in JavaScript.

Three forces make this a decision rather than a feature. Storage is a persistence choice that
affects the schema of eighteen tables. The upload is an untrusted binary input reaching a
server-side image library, which is a security boundary. And the editor has to exist three times
over unless the transport is chosen to make one implementation serve all three.

## Decision

- **A `Photo` is its own Active Record model**, not a `photo`/`photo_path` pair on every table. It
  `belongs_to :universe` and `has_one_attached :file`. Eighteen models include a `HasPhoto` concern
  that declares `belongs_to :photo, optional: true`, so each of those tables carries one nullable,
  indexed `photo_id`. Defining the bytes, the normalization, and the optionality once is worth more
  than eighteen identical column pairs.
- **The stored file is only ever the finished square.** `PhotoProcessing` resizes to 300×300,
  re-encodes as JPEG, and strips metadata, and nothing else is written: not the original, not an
  intermediate. This is also what makes the stored bytes safe to serve — the attachment is an image
  this application produced, whatever arrived.
- **The server is the authority, the browser is the editor.** The cropper chooses the square so the
  author gets to decide what matters; the server crops and resizes again regardless, because a
  request can skip the cropper entirely. A client is not trusted with the stored size.
- **The editor sends a `data:` URL in one ordinary text field**, not a multipart body. That is the
  transport decision that makes one control serve all three page patterns: the JSON modals already
  post a form-encoded body, the taxonomy modal is built from DOM APIs, and a Turbo form posts a
  string. None of them changes how it submits.
- **The control is one Stimulus controller that builds its own widget.** The three page patterns
  produce the same bare container and nothing else. One implementation means the three surfaces
  cannot drift, and it needs no new npm or importmap dependency.
- **The request never carries a photo id.** It carries the cropped square (`photo_data`) or a
  remove flag (`remove_photo`); the model creates the `Photo` inside the record's own universe. A
  cross-universe assignment is therefore not reachable from the interface at all, and
  `photo_belongs_to_the_universe` keeps a direct model write honest, because a foreign key cannot
  prove two rows share a universe.
- **A `Photo` has no URL method.** An Active Storage attachment's URL is built by the request that
  serves it, so a view asks the router through one helper, `record_photo_url(record)`. A model
  method could only return `nil`.
- **On a details page, a photo is the left part of the surface card, and its absence is invisible.**
  A record with no photo renders exactly what it rendered before photos existed: the identity block
  is the same shared partial in both branches, so there is one layout rather than two.
- **Replacing a photo is transactional.** The new `Photo` is created after the record saves, inside
  the same transaction; the one it superseded is destroyed only after that transaction commits, and
  only while nothing else still refers to it. A rejected save never takes the picture away with it.

## Consequences

### Benefits

- One optional image on eighteen models without eighteen column pairs, eighteen validation
  callbacks, and eighteen upload paths.
- The original never touches disk, and neither does its metadata, so the largest and most
  privacy-bearing part of an upload does not outlive the request that carried it.
- Three editors, one implementation. A future page pattern gets a photo by rendering the same bare
  container.
- The existing mutation contracts in [ADR 0011](0011-modal-json-mutation-contract.md) are
  untouched, so no JSON contract, CSRF decision, or error-rendering path had to change.

### Costs and constraints

- **An image library is now a runtime prerequisite.** libvips is used when installed (Docker, CI)
  and ImageMagick is the fallback, so a workstation needs one of the two. Without either, an upload
  fails as an ordinary field error.
- **The crop is lossy and fixed-size.** One square, 300×300, forever. A print-quality export or a
  second size would need a variant, and the Active Storage variant tables are created but unused.
- **A `data:` URL is base64, so it is about a third larger than the image** and is held in memory
  during the request. `PhotoProcessing` bounds that at 8 MB. This is a deliberate trade for not
  changing how three editors submit.
- **A `Photo` can be orphaned.** A record destroyed through a path that does not run the concern's
  callbacks keeps its `Photo` row. Destroying the record's universe does remove them, because
  `Photo` belongs to it; a general sweep for orphans would be a separate decision.
- **`Photo::OWNER_CLASS_NAMES` is a list that can go stale.** It is kept equal to the `HasPhoto`
  includers by a model test, because a missing entry is a photo destroyed while another record still
  shows it. A new photo-capable model must add itself in both places or the test fails.
- **The cropper is keyboard-operable on purpose.** Dragging is a pointer gesture and a keyboard has
  none, so the arrow keys and four move buttons are real controls. That is more code than a drag
  alone, and it is the difference between a usable and an unusable editor.

## Alternatives considered

### A `photo` / `photo_path` column pair on every table

Rejected. It is eighteen copies of the same nullable pair, and every consumer of an image has to
know which of two columns to read. One `Photo` row keeps the size, the encoding, the attachment, and
the ownership rule in one place, and the reference is a real foreign key. It also makes "this photo
belongs to that universe" a single validation instead of a convention.

### `multipart/form-data` for the photo

Rejected. It would have forced a change to every mutation contract: the JSON modals submit the form
themselves as `application/x-www-form-urlencoded` and would need a real multipart body, the taxonomy
modal's hand-assembled form would need one too, and both would need their file parts read by a
new code path. A `data:` URL is one text field that every existing submitter already carries.

### A third-party cropper dependency (Cropper.js and similar)

Rejected. The import map currently serves three pinned libraries and this is one square crop with a
pan and a zoom. A canvas cropper is a few hundred lines of DOM code that `bun test` can cover
without a browser, and it avoids a new supply-chain surface and a new lifecycle (the file also
carries its own stylesheet, which would have to fight the existing custom layer). The cost is that
the widget is ours to maintain.

### A single `Photo` reused by several records

Rejected. A photo belongs to the record it was uploaded for, and an upload always creates a new row.
Sharing would need reference counting, and the "destroy the one I replaced" rule could take a
picture away from a record that still shows it. Development data and a console can share one
deliberately, which is why the replacement check still asks whether anything else refers to it.

### Storing the original and deriving the square on read

Rejected. It keeps the largest and most privacy-bearing bytes indefinitely, and it makes every
details page a resize operation. Storing only the finished square means the read path is a plain
attachment fetch, and the author can delete the original by deleting the photo.

### Making the photo required

Rejected, and recorded here because it is the one that would have been cheapest to build. Optional
is the requirement, and a required photo would have meant a migration default, a placeholder image,
a validation on eighteen models, and a change to every existing record and fixture.

## Related documentation

- [`../features/photos.md`](../features/photos.md)
- [`../data_model.md`](../data_model.md#photos)
- [`../conventions.md`](../conventions.md)
- [`../development.md`](../development.md#testing-record-photos)
- [`../db/data/README.md`](../../db/data/README.md)
- [0001](0001-universe-and-story-scope.md)
- [0002](0002-json-crud-with-stimulus-editors.md)
- [0011](0011-modal-json-mutation-contract.md)
- [0012](0012-client-side-verification-and-csrf.md)
