# Record photos

[ADR 0015](../adr/0015-record-photos.md) decides the shape; this is the whole contract. The schema
is in [data_model.md](../data_model.md#photos) and the test workflow is in
[development.md](../development.md#testing-record-photos).

A record may carry one photo, and a photo is always optional. Eighteen models include `HasPhoto`
(`app/models/concerns/has_photo.rb`): `Universe`, `Story`, `Section`, `Scene`, the six content
models, and all eight `_tag` models. A record with no photo is completely normal, and no controller
force-creates one.

## Model contract

`HasPhoto` gives a model the whole optional-photo contract:

- `belongs_to :photo, optional: true`, plus a `photo_belongs_to_the_universe` validation. A
  `Photo` from another universe is refused.
- Two **virtual writers**, never a `photo_id`: `photo_data=` receives the cropped square as a
  `data:` URL, and `remove_photo=` clears it. The editor never sends an id at all, so a
  cross-universe assignment is not reachable from the interface.
- The bytes become a finished 300×300 square in a `before_validation`. An unreadable upload is an
  ordinary field error, and the record is never written.
- The `Photo` row is created in an `after_save`, because a `Universe` has no id of its own until it
  saves. A `Universe` is its own photo scope.
- The photo that was replaced is destroyed in an `after_commit`, only while nothing else still
  refers to it. A rejected save never takes the picture away.
- `Photo::OWNER_CLASS_NAMES` is the explicit list of models that may point at a `Photo`, kept equal
  to the `HasPhoto` includers by a model test.

`Photo` has **no `url` method**: an Active Storage attachment's URL belongs to the request that
serves it, so a view asks the router through `ApplicationHelper#record_photo_url(record)`, which
returns `nil` when there is no photo. A model that exposed `url` could only ever return `nil`.

## The stored file is the server's answer, never the upload

`PhotoProcessing` (`app/services/photo_processing.rb`) is the authority on what is stored: it
resizes and re-encodes whatever arrives to a 300×300 JPEG with its metadata stripped, so a request
that skipped the browser cropper still cannot store something else. Submitted bytes are checked
against a content-signature allowlist (JPEG/PNG/GIF/WebP) **before** any image library sees them,
so a client that labels an SVG as `image/png` is refused, and payloads over 8 MB are turned away.
libvips is used when installed (Docker, CI) and ImageMagick is the fallback, so a workstation with
only that still works.

The consequence worth stating plainly: the stored file is only ever the finished crop, so the
original upload is never written and never needs to be cleaned up.

## One control, three page patterns

The photo field is the same control everywhere, which is why it is built in one place:

- `shared/_photo_field` renders a bare container carrying `data-controller="photo-crop"` and the two
  field names. `photo_crop_controller.js` builds the file input, the preview, the remove checkbox,
  the square stage, and its controls itself, with DOM APIs only.
- The taxonomy editor's `photo` field branch produces the same container from the shared
  `ModalFields::PHOTO_FIELD` descriptor rather than building a second widget, so the surfaces
  cannot drift. That one descriptor is why the field cannot be spelled one way in a tag taxonomy
  and another in a content editor.
- The transport is a `data:` URL in a normal text field, **not** a multipart body. That is what
  lets the JSON modals (which already post `application/x-www-form-urlencoded`), the DOM-built
  taxonomy modal, and a plain Turbo form all carry a photo without changing how they submit.
- One modal form serves every row, so `modal_form_controller.js#loadRowState` dispatches
  `photo-crop:load` with the row's own photo URL before the modal opens. Without it a row would
  open showing the previous row's photo.
- `photo_crop_controller.js` must stay a **named** class export: the Stimulus registration name is
  derived from the file, and the controller self-references its own static constants.

A file opens in a square viewport the author can drag or move with the arrow keys; confirming draws
that square to a canvas and hands the result to the form as a `data:` URL.

## Visibility and layout

- A read-only member and a guest are offered **no cropper at all**: the field is rendered only where
  a mutation control already belongs.
- A record's photo shows in the **left** part of its details-page surface card. A record without one
  renders exactly what it rendered before photos existed — see
  [conventions.md](../conventions.md#record-details-pages).
- `PhotoParams` (`app/controllers/concerns/photo_params.rb`) is
  `PHOTO_PARAMS = [ :photo_data, :remove_photo ]`. Every photo-capable controller
  `include PhotoParams` and splats `*photo_params` into its `params.expect`, so the two virtual
  field names are declared once instead of in eighteen controllers. They are never a `photo_id`,
  which is what makes a cross-universe photo impossible to assign from a request.
- Author-chosen photo content is data, not theme: a stored image is left alone in dark mode. See
  [visual_design.md](../visual_design.md).
