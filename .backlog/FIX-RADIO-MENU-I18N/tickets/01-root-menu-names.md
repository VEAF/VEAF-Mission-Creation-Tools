# 01 — The 14 root menu names, and the load-time trap

Status: ✅ done 2026-08-13 — 14 root names (not 13: veafCarrierOperations declares three), resolved at build time, both languages pinned
Type: fix
Files: `src/scripts/veaf/veafI18n.lua`, the 12 modules declaring a `RadioMenuName`, `test/lua/`

## The change

`RadioMenuName` stops holding a display string and holds an **i18n key**:

```lua
veafAssets.RadioMenuName = "menu.assets.root"      -- was "ASSETS"
```

and the point of use resolves it: `veafRadio.addMenu(veaf.t(veafAssets.RadioMenuName))`.

That is a deliberate contract change on a public field, and it goes in the changelog: a third-party
script reading `veafAssets.RadioMenuName` to display it would now show a key. `veaf.t` falls back to
the key itself, so a forgotten translation shows `menu.assets.root` on screen — ugly, and visible,
which is the point.

## Why the resolution cannot happen at declaration

`veaf.config.language` is set **after** the module files load. Putting `veaf.t(...)` on the
`RadioMenuName` line resolves it before the mission's language is known, so every server would get
French, silently. This is the load-time trap the PRD names.

## The names, with David's arbitration a applied

| Module | Was | `fr` | `en` |
|--------|-----|------|------|
| `veafRadio` | `VEAF` | `VEAF` | `VEAF` |
| `veafSpawn` | `SPAWN` | `APPARITION` | `SPAWN` |
| `veafCombatZone` | `COMBAT ZONES` | `ZONES DE COMBAT` | `COMBAT ZONES` |
| `veafCombatMission` | `MISSIONS` | `MISSIONS` | `MISSIONS` |
| `veafCasMission` | `CAS MISSION` | `MISSION CAS` | `CAS MISSION` |
| `veafTransportMission` | `TRANSPORT MISSION` | `MISSION DE TRANSPORT` | `TRANSPORT MISSION` |
| `veafAssets` | `ASSETS` | `MOYENS` | `ASSETS` |
| `veafCarrierOperations` | `CARRIER OPS` | `OPS PORTE-AVIONS` | `CARRIER OPS` |
| `veafWeather` | `WEATHER AND ATC` | `MÉTÉO ET ATC` | `WEATHER AND ATC` |
| `veafNamedPoints` | `NAMED POINTS` | `POINTS NOMMÉS` | `NAMED POINTS` |
| `veafMove` | `MOVE` | `DÉPLACER` | `MOVE` |
| `veafMissileGuardian` | `GUARDIAN` | `GUARDIAN` | `GUARDIAN` |
| `veafShortcuts` | `SHORTCUTS` | `RACCOURCIS` | `SHORTCUTS` |

`VEAF` and `GUARDIAN` are proper nouns and stay identical in both languages — stated so a reviewer
does not read them as an oversight.

## TDD

- Failing first: with `veaf.config.language = "fr"`, the root menu title passed to `veafRadio.addMenu`
  must be the French label, for every module that declares one — enumerated from the source, not
  sampled.
- Failing first: the same assertion with `language = "en"` must give the English label. Two languages,
  because a test on one only would pass on a hard-coded string.
- A test asserting `RadioMenuName` is a **key** (`menu.*.root`) and that the key exists in the
  catalogue, so a typo in the key is caught here rather than on screen.

## Acceptance criteria

- [ ] The 14 names resolve through `veaf.t` at build time, both languages pinned by tests.
- [ ] `test-lua` + stylua green.
