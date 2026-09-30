# ADR 0012: Verify the client-side code with Bun tests, Biome, and a real browser CSRF check

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [`../architecture.md`](../architecture.md),
  [`../conventions.md`](../conventions.md),
  [`../development.md`](../development.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0011](0011-modal-json-mutation-contract.md)

## Context

The shared editors introduced by [ADR 0002](0002-json-crud-with-stimulus-editors.md) and
[ADR 0011](0011-modal-json-mutation-contract.md) put the security-sensitive part of a mutation —
building rows and messages from user-controlled values, serializing the payload, and attaching the
CSRF token — in client-side JavaScript. That code had two blind spots:

- Nothing checked it. There was no JavaScript test runner and no JavaScript linter, so a behavioral
  regression in a controller surfaced as a browser test that already looked green, or as a
  production report. Two defects had been found by hand while debugging browser tests — a
  multi-select that was given a second `[]`, and a new method name that silently replaced an
  existing one and broke every taxonomy editor — and a third, a cancelled rename that kept the
  author's unsaved text, sat in the tree unnoticed until the first unit test run. Brakeman does not
  read client-side code at all.
- The test environment disabled request forgery protection, so no test proved that a `fetch` from
  those editors actually carried a token. Turning protection on for the whole request suite would
  have coupled several hundred tests to token plumbing without testing anything the two dedicated
  files do not test directly.

There is also no bundler for the application's own JavaScript: the import map serves Stimulus and
Bootstrap from `vendor/assets`, so a test runner cannot resolve those specifiers from
`node_modules`. That has to be handled explicitly rather than by adding the runtime to
`package.json`, which would add a second copy of the framework the browser actually runs.

## Decision

- Client-side logic is unit tested with **Bun's built-in test runner** (`bun run test:js`) in
  `test/javascript/`, one file per controller, using a real DOM from `happy-dom`.
- `test/javascript/setup.js` provides that DOM and replaces `@hotwired/stimulus` and `bootstrap` with
  minimal stubs, so the controllers under test are the exact files the browser loads and no
  framework is duplicated in `node_modules`. `bunfig.toml` preloads it.
- **Biome** (`bun run lint:js`, recommended rules) lints `app/javascript` and `test/javascript` in
  CI next to RuboCop. It does **not** format: the controllers keep their hand-written house style.
- A **gate test** fails when a new `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write`
  sink appears in `app/javascript` without a reviewed, commented exception. This keeps the
  DOM-API-only rule (former quirk #8) enforceable rather than advisory.
- `config.action_controller.allow_forgery_protection` stays **false** for the fast request suite.
  The cases that must prove a token is used wrap their own window in `with_forgery_protection`:
  `test/controllers/csrf_mutation_test.rb` for the server and `test/system/csrf_token_test.rb` for
  a real browser driving both `fetch` implementations.
- A JSON mutation whose token is refused answers **403**, not the generic `422` page, so the shared
  editor reports a refusal ("reload the page and sign in again") instead of claiming the server
  explained nothing. HTML requests keep Rails' own handling.
- Browser coverage stays the authority for what only a browser can show: focus, Turbo navigation,
  layout, and a real token on the wire. Unit tests do not replace it, and the browser suite is still
  not exhaustive.

## Consequences

### Benefits

- A client-side regression now fails in about a second instead of being discovered in a browser
  test or in production.
- The DOM-XSS invariant and the CSRF contract are enforced by a check, not by a comment.
- The two editors that mutate through `fetch` are covered by the same command, so a new editor has
  an obvious place to add its cases.
- The toolchain adds two development-only packages and no new runtime service, framework, or
  bundler.

### Costs and constraints

- `bun test` is Bun-specific; the project's JavaScript tooling now assumes the pinned Bun version,
  the same as the CSS pipeline.
- The stubs in `test/javascript/setup.js` must be updated if a controller starts importing
  something else from the import map, and a unit test must not rely on behavior a real Stimulus or
  Bootstrap instance provides. Cases that need the real thing belong in `test/system`.
- happy-dom is not a browser. Where its emulation differs from a browser — `FormData` for a
  multi-select is the case already found — the test stubs the browser contract and says so.
- The fast request suite still does not verify tokens, so a new mutation path must be added to one
  of the two CSRF files deliberately.

## Alternatives considered

### Turn forgery protection on for the whole test environment

Rejected for now. It would require every request test that mutates to fetch and replay a real token,
changing several hundred tests to test plumbing that two focused files cover directly. If the
request suite ever grows a helper that does that transparently, this decision should be revisited
with a new ADR.

### Set the flag from an environment variable in the system-test job

Rejected. The test environment is configured before any task runs, so the switch could only come
from the caller; a developer running `bin/rails test:system` locally would silently get the weaker
suite. Opting in inside the test that needs it keeps the guarantee with the test.

### Use Jest, Vitest, or a Node test runner

Rejected. Each needs its own runtime and a DOM shim anyway, while Bun is already the pinned tool for
this repository's JavaScript. Vitest additionally expects a Vite-based toolchain the project does
not use.

### Add a full JavaScript framework to `package.json`

Rejected. The browser loads Stimulus and Bootstrap from `vendor/assets` through the import map.
Installing them for tests would create a second, unpinned copy of the runtime the controllers were
written against.

### Reformat the controllers with Biome

Rejected as unrelated churn. The lint step reports real problems; reformatting ~60KB of reviewed
controller code belongs to its own change.

### Run a JavaScript coverage gate

Rejected for now. Aggregate client-side coverage would be a metric without a use case yet, and
[ADR 0006](0006-data-factor-quality-guidance.md) treats exactly that kind of target as a bad
reason to add tooling.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../conventions.md`](../conventions.md)
- [`../development.md`](../development.md)
- [`../delivery_history.md`](../delivery_history.md)
- [`../known_quirks.md`](../known_quirks.md)
- [`../../AGENTS.md`](../../AGENTS.md)
- [0011](0011-modal-json-mutation-contract.md)
