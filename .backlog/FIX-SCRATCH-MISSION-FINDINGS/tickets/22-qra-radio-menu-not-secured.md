# 22 — `radio_menu: true` on a QRA hands Start / Stop to every player, unsecured

Status: ⬜ ready
Type: fix + doc
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py`,
`doc/mission-maker/scripts/veafQraManager*.md`, the AirWaves doc, tests

## Origin

GermanyCW-v6 rebuild of 2026-09-24: red QRAs with `radio_menu: true`.

## Measured

In the generated `veaf-config.lua`: `veafRadio.command("Arrêter QRA Berlin", ...)` with no security
level. On a public server a blue player can stop the red QRA they are about to fly over.

## Cause

`_emit_module_radio_menu` (`lua_config_generator.py:1399-1425`) builds a user menu whose commands are
emitted as plain `veafRadio.command(label, call)` (`lua_config_generator.py:1368`). The only knob is
`radio_menu_restrict_to_group` (l. 749), which hides the menu from everyone but one group — no
security level. AirWaves use the same path (`lua_config_generator.py:871-878`).

The doc presents the menu as "un contrôle F10 pour le Mission Master" (`veafQraManager.md:109`) and
does not say that without `radio_menu_restrict_to_group` every player gets it.

## Done when

- At minimum: the QRA and AirWaves docs (FR/EN) warn that the menu is open to all players unless
  restricted to a group
- Better: a secured option for the generated commands (decide whether it becomes the default), tested
  on the generated Lua
