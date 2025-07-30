# Story Maker

A Rails 8 application for creating and managing stories with locations and taxonomies.

## Features

- **Stories**: Create and manage story content
- **Locations**: Organize story locations with types
- **Taxonomies**: Hierarchical classification system for content organization

## Taxonomy System

The application includes a flexible taxonomy system for organizing content:

### Taxonomies
- **Name**: Display name for the taxonomy
- **Description**: Optional description of the taxonomy's purpose
- **Slug**: URL-friendly identifier (auto-generated from name)
- **Fixed**: Boolean flag to prevent deletion of important taxonomies

### Taxons
- **Name**: Display name for the taxon
- **Parent**: Optional parent taxon (creates hierarchical structure)
- **Taxonomy**: Belongs to a specific taxonomy

### Key Features
- **Automatic Root Taxon**: Each taxonomy automatically creates a root taxon with the same name
- **Tree Structure**: Taxons can be nested in unlimited levels
- **Fixed Protection**: Fixed taxonomies and their root taxons cannot be deleted
- **JavaScript UI**: Interactive tree management with expand/collapse functionality
- **JSON API**: Full REST API support for AJAX operations

### Usage

1. **Create a Taxonomy**: Navigate to `/taxonomies/new`
2. **Add Taxons**: Use the interactive tree interface on taxonomy show pages
3. **Manage Hierarchy**: Drag and drop or use the form interface to organize taxons
4. **API Access**: All operations support JSON responses for frontend integration

### Sample Data

The application includes sample taxonomies:
- **Categories**: Fixed taxonomy for main content organization
- **Tags**: Flexible tagging system
- **Genres**: Story genres and themes

Run `rails db:seed` to populate with sample data.

## Getting Started

1. Clone the repository
2. Run `bundle install`
3. Run `rails db:create db:migrate db:seed`
4. Start the server with `rails server`
5. Visit `http://localhost:3000`

## Testing

Run the test suite:
```bash
rails test
```

Run specific test files:
```bash
rails test test/models/taxonomy_test.rb
rails test test/controllers/taxonomies_controller_test.rb
```
