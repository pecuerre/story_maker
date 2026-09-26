import { GlobalRegistrator } from "@happy-dom/global-registrator"
import { mock } from "bun:test"

// A DOM for the controller unit tests. Nothing here talks to Rails or a
// browser: these tests cover the shared editor logic in isolation.
GlobalRegistrator.register({ url: "http://localhost/" })

// The application serves Stimulus and Bootstrap from the import map
// (`config/importmap.rb` → `vendor/assets`), not from `node_modules`, so the
// specifiers below cannot be resolved by the test runner. Only the base class
// is needed to instantiate a controller, and a unit test never opens a dialog.
mock.module("@hotwired/stimulus", () => ({ Controller: class {} }))
mock.module("bootstrap", () => ({}))
