# Known Quirks & Tech Debt

Verified **open** oddities in this codebase — things that look like bugs, are bugs, or will
surprise you. Each entry was checked against the code (paths given); when one gets fixed, move
it to [resolved_quirks.md](resolved_quirks.md) instead of deleting it, so the fix history
survives. Index of all docs: [README.md](README.md).

## Correctness / security observations

No open correctness or security observations are currently tracked. The former authorization and
universe-visibility issues are recorded in [resolved_quirks.md](resolved_quirks.md).

## Development workflow observations

4. **Disposable universe data is still coupled to `db:seed`.** `db/data/` is intentionally
   development-only: one subdirectory per universe (`dark/`, `lotr/`, and future universe slugs)
   contains the records used to exercise that universe. The current `dark` and `lotr` loaders use
   `create`/`create!`, and `db/seeds.rb` still loads a hardcoded `["dark", "lotr"]` list, so the
   loaders are not safe to rerun. This is not a request to make temporary feature data production-
   idempotent; the intended fix is an explicit, environment-guarded development load/reset task
   that keeps `db/seeds.rb` production-safe. The current coupling is tracked as a transitional
   implementation gap in [ADR 0004](adr/0004-universe-data-and-demo-seeding.md).
