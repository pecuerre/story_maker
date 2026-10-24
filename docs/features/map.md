# Map

Map is a read-only Universe workspace that brings together the existing Location hierarchy and
directional Routes. It derives its content from the current, already-authorized Universe; it does not
store a Map record or Location coordinates. The page uses the universe authorization rules in
[ADR 0005](../adr/0005-universe-access-levels.md).

## Page

Open **Map** from the Universe Bible sidebar at `/u/:universe_slug/map`. The page shows:

- live Locations as a nested, accessible list in their hierarchy order, with each Location linking to
  its details page;
- live Routes as a separate list, with their direction shown from the `from_location` to the
  `to_location`, endpoint Location links, and a Route details link. Optional distance and travel-time
  values are shown when present.
- an automatically arranged SVG diagram above those lists: Location cards follow the hierarchy from
  left to right, solid neutral lines join parents to children, and dashed primary-color arrows show
  Route direction. The layout uses the live records on each request; it is not stored.

The Location count in the page header counts the live Locations shown. When there are no Locations,
the page explains the empty state and links to Locations. When Locations exist but no Routes do, the
Routes section explains that state and links to Routes. Empty copy distinguishes readers who can
write from guests and read-only members. Each SVG Location card is a keyboard- and touch-accessible
link to its details page. The Location and Route lists remain the text alternative to the diagram,
with their full hierarchy, endpoint details, and record links. The diagram scrolls horizontally when
its derived width exceeds the viewport and uses Bootstrap theme variables for both light and dark.
Map itself has no editing controls.

The diagram derives its coordinates at render time. It introduces neither persisted Location
coordinates nor a Map model or external map provider.
