# 03 — Small dead ends: the fog constant, the stale CLI help

Status: ⬜ ready
Type: fix
Files: `src/scripts/veaf/veafWeather.lua`, `src/python/veaf-tools/veaf_build/cli.py`, tests

## The fog menu entry that references a constant that does not exist

`veafWeather.lua:1714` passes `veafWeather.FOG_ANIMATED_5_NO` — the generated grid produces
`FOG_ANIMATED_5M_NO` (the `M` is part of the pattern, `veafWeather.lua:1612`). The menu entry for
"animated fog, none" therefore hands `nil` to its handler. Fix the reference; add the test that
would have caught it (asserting every constant the menu wires actually exists on the module —
enumerated from the menu-building code, not sampled, per the sweep rule).

## The CLI help that names a command the updater does not have

`veaf_build/cli.py:238` and `:257` (the `--prerelease` help text and the `publish` docstring) tell
the user to run `veaf-tools-updater update --tag …` — the updater has **no subcommands**
(`veaf-tools-updater.py:891` is a bare `typer.run(main)`); the invocation is
`veaf-tools-updater --tag published-v<version>`. `TOOLS_REFERENCE.md` states this correctly; the
code's own help is the stale side. Fix both strings (and their i18n keys if routed through the
catalog).

## Acceptance criteria

- [ ] Fog: the enumerated menu-constant test fails before the fix, passes after; `test-lua` green.
- [ ] CLI: help strings corrected in both locales if localised; a grep for `updater update` over
      `src/` returns nothing.
- [ ] Full Python gate green.
