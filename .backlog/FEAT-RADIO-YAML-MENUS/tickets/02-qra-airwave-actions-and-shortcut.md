# 02 — `qra.*` / `airwave.*` actions + per-module `radio_menu` shortcut

Status: ✅ done

## Context

Extends the dispatch (ticket 01) with the two "addressable by name" subsystems that
have no standard radio menu:

- QRA — `veafQraManager.get("<name>"):start()` / `:stop()` (registry auto-populated
  in `setName`, `veafQraCore.lua`).
- AirWaves — `veafAirWaves.get("<name>"):start()` / `:stop()` / `:reset()`
  (`veafAirWaves.zones`, `veafAirWaves.get`).

Plus **mechanism 1**: a `radio_menu` shortcut on a QRA definition / AirWave zone that
auto-generates the start/stop(/reset) commands, so the maker does not hand-write the
`RADIO.user_menus` tree for the common case.

## Tasks

- [ ] Dispatch: `qra.start` / `qra.stop` (target key `qra:`),
      `airwave.start` / `airwave.stop` / `airwave.reset` (target key `airwave:`).
      These are usable in a `RADIO.user_menus` tree (ticket 01) targeting any QRA /
      AirWave by name — including ones declared in Lua.
- [ ] `modules.QRA.definitions[].radio_menu: true` → auto-emit a submenu with
      "Démarrer / Arrêter <name>" for that QRA. Optional
      `radio_menu_restrict_to_group` (group name → ticket 04).
- [ ] Same shortcut on AirWave zones (locate the AirWaves YAML definition surface;
      see `_emit_airwave_zone` in `lua_config_generator.py`): start / stop / reset.
- [ ] i18n the generated command labels (FR/EN) via the existing `t()` mechanism.

## Definition of Done

- A QRA/AirWave definition with `radio_menu: true` yields its control submenu;
  `qra.*` / `airwave.*` also work inside a `RADIO.user_menus` tree by name.
- Unit tests cover shortcut emission (QRA + AirWave) and dispatch-by-name.
- Quality ratchet + coverage gate obligations (see PRD).
