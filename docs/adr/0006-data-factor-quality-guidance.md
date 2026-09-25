# ADR 0006: Treat external repository scores as directional quality signals

- **Status:** Accepted
- **Date:** 2026-09-25
- **Related:** [`../data_factor_guidance.md`](../data_factor_guidance.md), [`../backlog.md`](../backlog.md), [`../known_quirks.md`](../known_quirks.md), [`../../AGENTS.md`](../../AGENTS.md)

## Context

The DataFactor report received on 2026-09-25 assigned the repository a score of 61.1 and suggested
sustained development, a one-command container setup, coverage enforcement, structured logging,
error tracking, credential cleanup, dependency improvements, and better documentation. The report is
an automated snapshot: some observations are already stale (`/up` and `bun.lock` exist), its score
weights and offer estimates are external, and it does not account for every project-specific
security or data-boundary risk.

The repository already has a date-based changelog, paired-test conventions, a development-only data
boundary, centralized authorization, and verified security findings. A contributor could therefore
make the project worse by adding ceremonial commits, fake history, arbitrary thresholds, unused
services, or production demo data merely to satisfy a detector.

## Decision

- Treat external repository scores and recommendations as **directional evidence**, not product
  requirements, release gates, or targets to game.
- Verify every recommendation against the current tree, tests, configuration, and Git history.
  Record stale findings as corrections rather than carrying them forward as facts.
- Prefer useful, small vertical changes with Minitest coverage, matching documentation, and a dated
  `CHANGELOG.md` entry. Use the shared **NOW / LATER / NEVER** decision for work outside the current
  request.
- Put deferred implementation work in [`../backlog.md`](../backlog.md) and verified open gaps in
  [`../known_quirks.md`](../known_quirks.md). Do not silently add dependencies, services, refactors,
  releases, or deployment actions.
- Security, authorization, data integrity, privacy, reproducible operations, and the existing
  universe/story boundaries take priority over score improvements. A clean automated scan is not
  evidence that browser, logging, or production-boundary behavior is safe.
- Never fabricate commits, authors, dates, cadence, tags, releases, or coverage-only tests. Genuine
  teammate contributions retain their own identities. Do not weaken tests, scopes, response
  contracts, or secret protections to satisfy a metric.
- Evaluate coverage, observability, error tracking, container onboarding, and dependency tooling
  against a documented use case and acceptance criteria. The exact coverage threshold, logging
  library, tracker, Compose shape, and release policy are owner decisions, not defaults.

## Consequences

### Benefits

- Quality work remains connected to writer value, maintainability, and safety rather than an opaque
  score.
- Future agents can use the report as a backlog prompt while avoiding stale claims and metric gaming.
- Security findings and development-data boundaries remain visible even when an external report
  emphasizes easier-to-detect improvements.
- The repository can re-score after real changes without rewriting its history or weakening its
  domain contracts.

### Costs and constraints

- Some score signals will remain imperfect or unaddressed until a real product/operations need
  justifies the work.
- Coverage and observability work requires additional design and verification effort.
- Container onboarding cannot be documented as a quick win until the transitional seed boundary is
  made safe.
- A maintainer must periodically review the report's claims instead of treating the initial email as
  a permanent specification.

## Alternatives considered

### Implement every recommendation immediately

Rejected because the report is a snapshot, several findings are stale, and the suggestions include
unbounded choices such as a coverage number, external error tracking, and a production-oriented
container command. Blind implementation would expand scope and could weaken existing safety rules.

### Optimize the score through Git history, tags, or release markers

Rejected because those changes do not improve the application, violate the project's date-based
history policy, and would make maintenance signals less truthful.

### Make an arbitrary coverage percentage mandatory

Rejected before measurement. Aggregate coverage is diagnostic; the threshold should follow a real
baseline and must not replace authorization, failure-path, or browser tests.

### Add a full observability and container stack up front

Rejected until the owner defines privacy, redaction, retention, deployment, rollback, and
development-data requirements. A small, tested improvement is preferable to an unused service.

## Related documentation

- [`../data_factor_guidance.md`](../data_factor_guidance.md)
- [`../backlog.md`](../backlog.md)
- [`../known_quirks.md`](../known_quirks.md)
- [`../development.md`](../development.md)
- [`../../AGENTS.md`](../../AGENTS.md)
- [`../../CHANGELOG.md`](../../CHANGELOG.md)
