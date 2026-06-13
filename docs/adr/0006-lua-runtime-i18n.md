---
status: accepted
---

# Localize in-game VEAF messages — Lua runtime i18n (LUA-I18N-001 spike)

The Lua scripts running inside DCS had **no i18n**: every pilot-facing message
(`trigger.action.outText*`) was a hardcoded English literal. UXPILOT-FEEDBACK
shipped English-only pilot messages because there was nothing to localize
against. This note records the design (the runtime counterpart of the Python
tools' design-time i18n, `veaf_libs.i18n` + `locales/{en,fr}.json`).

## Decision

**Lookup function + catalog, French default.**

- **`veaf.t(key, ...)`** (in `veaf.lua`, the base module loaded everywhere — so it
  is always available, including in unit tests) resolves a catalog key to the
  active language and applies `string.format` to the extra arguments.
- **Catalog** `veaf.i18nCatalog = { ["key"] = { fr = "...", en = "..." } }` lives in
  a dedicated **`veafI18n.lua`** module, loaded first in the framework bundle. The
  function and the data are split so `veaf.t` exists even if the catalog is absent.
- **Active language** is `veaf.config.language`, emitted into `veaf-config.lua` by
  `lua_config_generator`. Source priority: `mission.yaml`'s `mission.language`
  (explicit per-mission choice) → otherwise the **tools' resolved language**
  (`current_language()`: `--lang` > `VEAF_LANG` > user config > OS locale > `en`),
  so a mission built by a French maker defaults to FR in-game and others to their
  locale. `veaf.I18N_DEFAULT_LANGUAGE = "fr"` in `veaf.lua` remains only as the
  ultimate runtime fallback (e.g. a mission with no `veaf-config.lua`).
- **Fallback** order: requested language → default language (`fr`) → the key
  itself, so a missing entry never crashes a message.

DCS does **not** expose a reliable per-pilot UI language, so the active language is
**mission-global**, not per-coalition/per-pilot.

## Consequences

- Adding a message: add a `["my.key"] = { fr, en }` entry in `veafI18n.lua` and
  call `veaf.t("my.key", ...)` at the call site.
- **Migration is incremental** (LUA-I18N-004): the framework + the UXPILOT
  pilot-feedback messages (`marker.command_failed`, `spawn.unknown_parameters`,
  `spawn.did_you_mean`) ship first; the remaining hundreds of `outText` literals
  are migrated module-by-module over time, never in a single big-bang PR.
- `veafI18n.lua` is picked up by the module scanner like any other `veaf*.lua`
  module; it carries an `Id`/`Version` but no `initialize` (pure data + logging).

## Implementation tickets

See the LUA-I18N lot in `backlog.md` (002 mechanism + wiring + tests;
003 migrate the pilot-feedback messages; 004 incremental migration of the rest).
