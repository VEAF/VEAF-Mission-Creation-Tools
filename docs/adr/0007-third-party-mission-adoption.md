---
status: accepted
---

# Adopt third-party missions via a generic `convert-other` + declarative profiles

VEAF wants to bring third-party `.miz` missions (first client: _Foothold_ by
Lekaa) onto the v6 toolchain, and re-import them from upstream on a recurring
basis (several times a month). The naive options were a Foothold-specific command
(`convert-foothold`) or a Foothold-specific YAML block parsed by VMCT — both put
author-specific knowledge into VMCT code for a single client, which violates the
"absolute simplicity / no speculative abstraction" rule **and** the project's
preference for generic detection (cf. CONVERT-CUSTOM-LOADER-HINT: "do not build a
brittle parser for one specific loader shape; instead detect generically").

## Decision

**The code is generic; the author-specific knowledge is data.**

- **`convert-other`** — a generic command that adopts any third-party `.miz` into
  a v6 mission folder: extract, generically detect embedded `.lua` scripts and the
  native load triggers, scaffold a `mission.yaml` (`custom_scripts:`,
  `strip_native_triggers:`, baseline VEAF `modules:`), and emit a report (à la
  `convert-v5-report.md`). It is the third-party counterpart of `convert-v5`,
  which migrates VEAF v5 missions — a distinct semantics, hence a distinct command.
- **Conversion profiles** — declarative data files carrying the only
  author-specific knowledge (script load order, native triggers to strip,
  `config_override` scaffold + target config file, versioned-name normalisation
  rules). Shipped as overridable defaults in VMCT (e.g.
  `src/defaults/convert-profiles/foothold.yaml`); a custom path may override them.
- **`--update`** — re-importing a new upstream version refreshes the third-party
  scripts, normalises versioned names (so `custom_scripts:` paths stay stable),
  preserves the already-tuned `mission.yaml`, and reports scripts added/removed
  upstream.

## Consequences

- VMCT code never mentions "Foothold"; Foothold is just the first profile. A new
  third-party family is a new data profile, not new code.
- The recurring re-import workflow is reproducible by any VEAF member without
  opening the Mission Editor — the native-trigger strip is declarative, not manual.
- The generic abstraction is extracted only at this first client; if a second
  third-party family later needs behaviour the profile data cannot express, the
  generalisation is revisited then (refactor-when-needed), not pre-built.
