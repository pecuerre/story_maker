# Universe Maker Rails App - Conventions Summary

## Core Patterns

### Database Schema
- All main models have: `name`, `description`, `universe_id` (FK), `parent_id` (self-ref FK), `position` (order), created_at/updated_at
- Parent models (Character, Location, Item, Section) each have a "_tag" taxonomy model
- "_tag" models are hierarchical but don't have a tag_id foreign key
- Both parent and "_tag" models support hierarchies via parent_id
- Position column defaults to 0, enables ordered lists

### Models
- All include `Hierarchical` concern (parent relationship, children collection, validations)
- Parent models (Character, Location, Item) belong_to their Tag model
- Tag models have_many of their parent model
- Complex relations (Relation, Ownership) connect multiple entities
- All models validate name presence
- Custom validators check universe_id consistency across relationships

### Controllers
- All include `MaintainsSiblingPositions` concern
- Typical actions: index, create, update, destroy (+ new for taxonomy editors)
- Strong params require primary fields and position/parent_id
- JSON responses for all mutations
- Universe scoping via Current.universe

### Routes
- Nested under `scope "s/:universe_slug", as: :universe`
- Resource routing: `resources :model_name`
- Relations/Ownerships limited to: index, create, update, destroy

### Views - Two Patterns

**Taxonomy Views (for "_ttag" models):**
- Use `shared/taxonomy_tree` partial with hierarchy rendering
- Use `taxonomy_tree_controller.js` for drag/drop reordering, inline editing
- Modal editing built into the tree via `modal_fields` helper data

**List Views (for main models like Character, Location):**
- Simple list layout with edit/delete buttons
- Use `modal_form_controller.js` for modal dialogs
- Character view uses simpler flat list instead of tree
- Locations view uses tree structure with location_tag_id field

### Helpers
- `modal_fields.rb` defines form fields for each model tag
- `*_tag_taxonomy_fitag` - fields for taxonomy editors
- `*_taxonomy_fields(options)` - fields for main models with tag selector
- `*_fields_json(obj)` - serializes object to JSON for modal population

### JavaScript Controllers
- `taxonomy_tree_controller.js` - manages hierarchy editing, drag/drop, inline name editing
- `modal_form_controller.js` - Bootstrap modal form management

### Navigation (Sidebar)
- Organized by universe theme questions:
  - HOW: Sections/Section Tags (Scenes future)
  - WHY: Plot, World Building (future)
  - WHERE: Locations + tags, Distances, Connections, Routes (future), Map (future)
  - WHO: Characters + tags, Relations + tags, Meetings, Dialogs (future)
  - WHEN: Events, Timeline
  - WHAT: Items + tags, Ownerships + tags

## Event Model (implemented)

Unlike Character/Location/Item, Event has no "_tag" taxonomy model:
1. `Event` model includes the `Hierarchical` concern (parent/position) plus self-referencing
   `before_event`, `after_event`, `simultaneous_event` associations
2. `EventsController` includes `MaintainsSiblingPositions`, flat list UI (no taxonomy tree)
3. Nested route under universe scope: `resources :events`
4. Modal form UI via `modal_form_controller.js`, matching Character/Ownership patterns
5. `modal_fields.rb` has `event_fields_json`
6. `TimelineLayout` (app/models/timeline_layout.rb) computes a layered ordering of events
   for the separate Timeline view (`get "timeline", to: "timeline#index"`)
7. Sidebar navigation links added in the "WHEN" section
