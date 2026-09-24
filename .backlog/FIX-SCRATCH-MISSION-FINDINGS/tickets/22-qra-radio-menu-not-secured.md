# 22 — `radio_menu: true` on a QRA hands Start / Stop to every player, unsecured

Status: ✅ done (#1000)
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

## Outcome

Decided with David (2026-09-24, option a): opt-in, nothing changes for existing missions.

1. Doc (QRA, AirWaves, FR/EN): the generated menu is open to every player unless restricted to a
   group, and any player taking that group's slot sees it.
2. `radio_menu_secured: true` on a QRA definition or an AirWaves zone emits the Start / Stop / Reset
   commands as `veafRadio.securedCommand`, a new node type of `createUserMenu` that goes through
   `veafRadio._proxyMethod` — the same check as the builder's `+` commands. A secured command needs
   the identity of a group (`_proxyMethod` refuses a click without one, REVIEW-SECURITY-LAYER), so it
   requires `radio_menu_restrict_to_group` and the build refuses otherwise. Mechanism 2 gets the same
   `secured: true` per command (`veafRadio` doc).
