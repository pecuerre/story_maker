# Pin npm packages by running ./bin/importmap

pin "application"
pin "i18n", to: "i18n.js" # the shared translation lookup the controllers read
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"
pin "tom-select", to: "tom-select.js" # @2.6.2
