# Routes

A Route records one directional travel path between two Locations in the same Universe. It may be
named; without a name its label is the `from → to` pair. A Route can also carry optional free-form
distance and travel-time values, because useful units vary between worlds (miles, leagues, days on
foot). It is one record for a path and its measurements, not a separate Distance record. The schema
and validation table are in [data_model.md](../data_model.md); the shared modal and response patterns
are in [conventions.md](../conventions.md).

## Workspace

Routes are universe-scoped world-building records, available from **Routes** in the Universe Bible
sidebar at `/u/:universe_slug/routes`. The workspace is a flat list with the established Bootstrap
modal editor. Each row names the path, links to both endpoint Locations, and may show its distance,
travel time, and description. The read-only details page is `/u/:universe_slug/routes/:id`.

Both endpoints are required and must belong to the current Universe. The editor's choices are limited
to Locations in that Universe, and the model repeats that rule so imports, APIs, and direct model
writes cannot create a cross-universe path. Multiple routes between the same locations are allowed;
endpoint order is meaningful. Distance and travel time are optional text, not normalized numbers or
unit enums, and the optional name is the label when present.

## Lifecycle and integrations

- Routes follow the Universe's read/write policy. Guests may read public Routes; signed-in writers
  may change them. The HTML mutations use the established redirect/re-render flow, and the external
  bearer-token API exposes JSON reads and draft-aware JSON mutations at `/api/u/:universe_slug/routes`.
- In draft-based collaboration modes, create, update, and delete are remembered through
  `DraftMutation`; a remembered create carries `universe_id` so the applier can resolve its scope.
- Routes are soft-deletable. Soft-deleting a Location cascades to Routes that use it as either
  endpoint; it does not affect Scenes or other Universe records. Restoring the Location alone leaves
  its Routes deleted; a Route can be restored separately after its endpoints are live again.
- Routes accept the shared optional photo and discussion controls, and are searchable by their
  displayed label and description. Search kind, scope, and command labels are translated in
  `searches.*`.
- Each checked-in development universe includes an example Route, loaded after its endpoint
  Locations. Verify the manifests with `script/demo check dark` and `script/demo check lotr`, then
  rebuild both local universes with `script/demo reset dark lotr`. Sign in as `dark@dark` using the
  development password configured in `.env`, then visit `/u/dark/routes` (or use `lotr@lotr` at
  `/u/lotr/routes`). The reset command reads the configured password without printing it; the full
  data workflow is in [development.md](../development.md#required-workflow-after-editing-demo-yaml).
