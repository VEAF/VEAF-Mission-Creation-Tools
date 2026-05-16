# veafCasMission — CAS Training Generator

**Module ID:** `CASMISSION` | **Version:** 1.15.x | **File:** `veafCasMission.lua`

---

## Purpose

Generates on-demand Close Air Support training zones with configurable size, armour, and air defence threat packages. Players can create, mark, skip, and clean up CAS targets from the F10 menu or via map marker commands.

---

## Dependencies

- `veafMarkers` — marker command handling
- `veafRadio` — F10 menu
- `veafSpawn` — unit spawning backend

---

## Enable

```lua
veafCasMission.initialize()
veafCasMission.start()
```

`start()` activates the watchdog that monitors the CAS group.

---

## Key Configuration Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafCasMission.Keyphrase` | `"_cas"` | Marker trigger text |
| `veafCasMission.SecondsBetweenWatchdogChecks` | `15` | Watchdog interval (s) |
| `veafCasMission.SecondsBetweenSmokeRequests` | `180` | Smoke cooldown (s) |
| `veafCasMission.SecondsBetweenFlareRequests` | `120` | Flare cooldown (s) |
| `veafCasMission.RedCasGroupName` | `"Red CAS Group"` | DCS group name for red CAS units |
| `veafCasMission.BlueCasGroupName` | `"Blue CAS Group"` | DCS group name for blue CAS units |
| `veafCasMission.RadioMenuName` | `"CAS MISSION"` | F10 submenu label |

---

## Marker Commands (Player-Facing)

```
_cas
_cas, size 3, defense 2, armor 3
_cas, side blue
```

Options:

| Option | Range | Description |
|--------|-------|-------------|
| `size` | 0–5 | Number of target units |
| `defense` | 0–5 | AA defence level (0=none, 5=heavy SAM) |
| `armor` | 0–5 | Armour level (0=infantry, 5=heavy MBT) |
| `side` | blue/red | Coalition of targets |

---

## F10 Radio Menu

- **Generate** — create a new CAS zone at a random or specified location
- **Smoke** — mark zone with coloured smoke (3-minute cooldown)
- **Flare** — mark zone with illumination flares (2-minute cooldown)
- **Info** — display zone position, composition, and status
- **Skip** — abandon current zone and generate a new one
- **Cleanup** — destroy all CAS units and reset

---

## Difficulty Reference

| Level | Typical units | AA defence |
|-------|--------------|------------|
| 0 | Infantry, jeeps | None |
| 1 | APCs, trucks | MANPADS |
| 2 | BMPs, BTRs | ZU-23 |
| 3 | IFVs, light tanks | ZSU-23-4 + SA-9 |
| 4 | MBTs | SA-13 + SA-15 |
| 5 | Heavy MBT mix | SA-6 / SA-11 |

---

## See Also

- [veafCombatZone](veafCombatZone.md) — for persistent, replayable zones
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafCasMission` API
