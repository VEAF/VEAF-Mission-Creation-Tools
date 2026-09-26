# veafCasMission — CAS Training Generator


**Module ID:** `CASMISSION` | **File:** `veafCasMission.lua`

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
```

> **Enabled by default** in the shipped `mission.yaml`. It is marker-driven (`_cas`) and needs no configuration — just place a `_cas` marker. The block below is only needed to tune it.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

`veafCasMission` has **no configurable YAML fields** of its own: it is enabled like the other modules.

```yaml
modules:
  CASMISSION:
    enabled: true          # default: true
    logLevel: info         # optional log-level override
```

> **CAP missions and combat missions are not configured here.** The `cap_missions:` and
> `combat_missions:` sections belong to the `COMBATMISSION` module, which is a separate module: see
> [veafCombatMission](veafCombatMission.en.md#configuration-missionyaml). They used to be documented
> on this page, which sent readers looking for one module's fields in another module's page.

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

| Option | Range | Default | Description |
|--------|-------|---------|-------------|
| `size` | 1–5 | 1 | Number of target units |
| `defense` | 0–5 | 1 | Air-defense level of the escort, rolled ±1 — see [what a level places](#defense-levels) |
| `armor` | 0–5 | 1 | Armour level (0=infantry, 5=heavy MBT) — see [what a tier holds](#armour-tiers) |
| `spacing` | 1–5 | 1 | Spacing between the group's units |
| `side` | blue/red | *(marker coalition)* | Coalition of targets |
| `disperse` | seconds | — | Targets disperse when attacked; a bare `disperse` = 15 seconds |
| `password` | text | — | Security password (see [veafSecurity](veafSecurity.en.md)) |


### What an armour tier holds {#armour-tiers}

Each tier draws at random from a list of vehicle types, picked by coalition and by the mission's era. Those lists are maintained by hand: a tier expresses *relative* power, which the DCS database does not carry — it states neither a vehicle's period nor its place on any scale.

Since 6.15.25 the modern armour DCS has added is in them: the T-84 Oplot-M and Stryker CV on the blue side, the T-90M and BMPT Terminator on the red one, among others. An automated check now verifies that **every** type named in those lists actually exists in the database — before it, an entry gone stale simply spawned nothing, and never said so.

### What a defense level places {#defense-levels}

The `defense` level drives two things: the **escort** of a section (one or two air-defense vehicles
added to the armour, infantry or trucks of `_cas`, `-armor`, `-convoy`…) and the complete
**air-defense group** that `-sam`, `-samSR`, `-samLR` and `-aaa` place (`_spawn samgroup`). For a real long-range battery, use `-samVLR` (`_spawn longrangesam`),
which depends on no level: see [the alias list](../../ALIASES.en.md).

**The level is rolled, not guaranteed.** For a requested level above 0: 60 % chance of getting it,
20 % of getting the level below, 20 % the level above. The air-defense group is then clamped to 0–5;
the escort has a tier 6, reached only by a 5 rolled upwards. The aliases also draw the requested
level from a range: `-sam` 1–5, `-samLR` 4–5, `-samSR` 2–3, `-aaa` 1–2. `list_shortcuts` (MCP)
returns those ranges for each alias.

**The level follows the mission's era** (`mission.era`):

- `MODERN` (default): the groups below.
- `COLD_WAR`: the types that entered service after 1980 — the armour lists' reference — are
  replaced: Avenger → Vulcan, Linebacker → Chaparral, Tor → Osa, Tunguska → Shilka, HQ-7 →
  Strela-10, Igla-S → Igla. Service dates are estimates, not sourced.
- `WW2`: flak only for the air-defense groups (Bofors, M45, 3.7-inch on the blue side; Flak
  30/36/37/38/41 on the red one), and **no escort**.

Air-defense groups in `MODERN`:

| Level | Blue | Red |
|-------|------|-----|
| 0 | AAV7, trucks (no air defense) | ZU-23, S-60 (0–1 each) |
| 1 | Vulcan, Avenger (0–1) | Shilka, ZSU-57-2 |
| 2 | Vulcan, Avenger | SA-9, Shilka, ZSU-57-2, S-60 |
| 3 | Gepard, Linebacker, Avenger | SA-13, SA-9, Shilka, ZSU-57-2 |
| 4 | Roland, Chaparral, Gepard | SA-8, SA-13, Shilka, ZSU-57-2 |
| 5 | Hawk, Chaparral, Gepard | SA-15, SA-8, SA-13, SA-19, ZSU-57-2, S-60 |

---

## F10 Radio Menu

The **CAS MISSION** submenu is created as soon as the module initialises, with a **HELP** entry. Once a mission has been generated (via the `_cas` marker), it additionally exposes:

- **Target information** — display target position, composition, and status
- **Skip current objective** — abandon the current zone and generate a new one (secured command)
- **Target markers → Request smoke on target area** — mark the zone with smoke (3-minute cooldown)
- **Target markers → Request illumination flare over target area** — mark the zone with an illumination flare (2-minute cooldown)

---

## Difficulty Reference

| Level | Typical units | Air-defense escort (red, `MODERN`) |
|-------|--------------|------------|
| 0 | Infantry, jeeps | None |
| 1 | APCs, trucks | ZU-23 or ZSU-57-2 |
| 2 | BMPs, BTRs | Shilka or ZSU-57-2, ×2 |
| 3 | IFVs, light tanks | SA-9 or SA-13, Shilka or ZSU-57-2 |
| 4 | MBTs | Shilka or ZSU-57-2, HQ-7 |
| 5 | Heavy MBT mix | SA-8 or SA-19, Shilka or SA-13 |

The level is rolled ±1 and follows the era: see [what a defense level places](#defense-levels).

---

## See Also

- [veafCombatZone](veafCombatZone.en.md) — for persistent, replayable zones
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafCasMission` API
