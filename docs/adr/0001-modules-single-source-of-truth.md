---
status: accepted
---

# `modules:` is the single source of truth for module configuration

In `mission.yaml`, a module or community script could be configured in up to
three places — a toggle under `modules:`, a detailed block under
`external_modules:`, and a top-level `qra:` block — which let the same module's
state diverge across sections. We collapse everything into one `modules:` block
where each module is a single entry with its config nested (Skynet, CTLD, CSAR
and QRA included), and remove `external_modules:` and top-level `qra:`.

## Considered options

- **Deprecate with a compatibility shim** (keep reading the old sections with a
  warning). Rejected: v6 has not been officially released, so there are no
  in-the-wild `mission.yaml` files worth a migration path, and the shim would be
  permanent maintenance cost for a transient problem.
- **Hard break** (chosen): drop support for `external_modules:` and top-level
  `qra:` outright. Existing pre-release missions must move their config under
  `modules:`; `convert-v5` emits the new shape directly.

## Consequences

Any pre-release `mission.yaml` using `external_modules:` or top-level `qra:`
stops validating and must be updated by hand. This is acceptable only while v6 is
unreleased — revisit (and add a migration) if discovered after the official v6
release.
