# 01 — Align CTLD's language on the mission's

Status: ✅ done 2026-08-16
Type: fix
Files: `src/scripts/veaf/veaf.lua`, `test/lua/dcs_mocks.lua`, `test/lua/test_veaf.lua`,
`doc/mission-maker/GUIDE.md` + `.en.md`

## The change

`veaf.ctld_alignLanguage()` sets `ctld.i18n_lang` from `veaf.config.language`, called by
`veaf.ctld_initialize()` just before `ctld.initialize()`.

Guards, each for a measured reason:

- **no `veaf.config.language`** → leave the engine's default alone;
- **no `ctld.i18n` table** → the engine is not the version we expect; do nothing rather than create
  a field it will not read;
- **no dictionary for that language** → log once at info and keep the engine's default, because
  `ctld.tr()` warns per unresolved string.

## Tests

Four, in `test_veaf.lua`: the mission language is followed; it is applied **before**
`ctld.initialize()` (the startup report is translated); an unknown language is left alone; no
mission language leaves the engine default. The `ctld` mock gains `i18n_lang` and the four
dictionaries the engine ships (`en`, `fr`, `es`, `ko`) so the "unknown language" case is real rather
than mocked away.

## Done when

`poetry run test-lua` passes with the four tests **actually executed** (check the count, not the
"OK"), and the mission-maker guide says CTLD follows `mission.language` unless the sidecar overrides
it.
