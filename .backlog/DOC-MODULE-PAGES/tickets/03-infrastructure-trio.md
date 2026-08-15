# 03 — `veafCommands`, `veafI18n`, `veafUnits`: the infrastructure trio

Status: ✅ done 2026-08-13 — three developer-facing pages in both languages, in nav, folded into the README's Foundation row
Type: feat
Files: three new page pairs under `doc/mission-maker/scripts/`, README rows, `mkdocs.yml`

- `veafCommands` — the central marker/text dispatcher: priorities, the mandatory per-handler
  security declaration (`veafCommands.lua:43-51,72-97,113-128`) — the mechanism `veafSecurity.md`
  describes without naming. Developer-facing; short.
- `veafI18n` — `veaf.i18nCatalog` consumed by `veaf.t()`; every player-visible string flows through
  it. Belongs beside `veafCacheManager`/`veafEventHandler` in the "Fondation" list.
- `veafUnits` — the group/unit database behind `_spawn group` (`veafUnits.Id = "UNITS"`); the
  README's data-modules table lists `dcsUnits.lua` but not this one.

Three short pages: what it is, who calls it, the two or three things a mission maker can configure
or must not touch. No verb tables to invent — cite the code.

## Acceptance criteria

- [ ] Three page pairs, in nav, README rows; `docs-check` green.
