import { GlobalRegistrator } from "@happy-dom/global-registrator"
import { mock } from "bun:test"
import * as i18n from "../../app/javascript/i18n"
import clientStrings from "./fixtures/client_strings.en.json"

// A DOM for the controller unit tests. Nothing here talks to Rails or a
// browser: these tests cover the shared editor logic in isolation.
GlobalRegistrator.register({ url: "http://localhost/" })

// The application serves Stimulus and Bootstrap from the import map
// (`config/importmap.rb` → `vendor/assets`), not from `node_modules`, so the
// specifiers below cannot be resolved by the test runner. Only the base class
// is needed to instantiate a controller, and a unit test never opens a dialog.
mock.module("@hotwired/stimulus", () => ({ Controller: class {} }))
mock.module("bootstrap", () => ({}))

// The application's own modules are pinned by bare specifier for the same
// reason, and a controller imports `i18n` the same way. The *real* module is
// registered rather than a stub, because the client-side string contract is
// exactly what these tests are about: a stub would let a controller read
// whatever the stub returned and still be green.
mock.module("i18n", () => i18n)

// The English blob is installed for every test, so a controller under test reads
// the same strings a real English page would.
//
// It is the *generated* fixture rather than a hand-written stub, and
// `ClientStringsTest` asserts the file is byte for byte what
// `ClientStrings#payload` produces — so these tests cannot go on asserting copy
// the application no longer shows, and a reworded sentence or a dropped key
// fails the Ruby suite instead of quietly making these tests lie.
i18n.use(clientStrings)
