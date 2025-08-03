// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

import { setupSlugAutoFill } from "generate_slug";

document.addEventListener("turbo:load", function() {
  // For stories form
  if (document.getElementById("story_name") && document.getElementById("story_slug")) {
    setupSlugAutoFill("story_name", "story_slug");
  }
  // For taxonomies form
  if (document.getElementById("taxonomy_name") && document.getElementById("taxonomy_slug")) {
    setupSlugAutoFill("taxonomy_name", "taxonomy_slug");
  }
});
