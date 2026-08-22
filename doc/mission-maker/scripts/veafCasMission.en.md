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
| `defense` | 0–5 | 1 | AA defence level (0=none, 5=heavy SAM) |
| `armor` | 0–5 | 1 | Armour level (0=infantry, 5=heavy MBT) — see [what a tier holds](#armour-tiers) |
| `spacing` | 1–5 | 1 | Spacing between the group's units |
| `side` | blue/red | *(marker coalition)* | Coalition of targets |
| `disperse` | seconds | — | Targets disperse when attacked; a bare `disperse` = 15 seconds |
| `password` | text | — | Security password (see [veafSecurity](veafSecurity.en.md)) |


### What an armour tier holds {#armour-tiers}

Each tier draws at random from a list of vehicle types, picked by coalition and by the mission's era. Those lists are maintained by hand: a tier expresses *relative* power, which the DCS database does not carry — it states neither a vehicle's period nor its place on any scale.

Since 6.15.25 the modern armour DCS has added is in them: the T-84 Oplot-M and Stryker CV on the blue side, the T-90M and BMPT Terminator on the red one, among others. An automated check now verifies that **every** type named in those lists actually exists in the database — before it, an entry gone stale simply spawned nothing, and never said so.

---

## F10 Radio Menu

The **CAS MISSION** submenu is created as soon as the module initialises, with a **HELP** entry. Once a mission has been generated (via the `_cas` marker), it additionally exposes:

- **Target information** — display target position, composition, and status
- **Skip current objective** — abandon the current zone and generate a new one (secured command)
- **Target markers → Request smoke on target area** — mark the zone with smoke (3-minute cooldown)
- **Target markers → Request illumination flare over target area** — mark the zone with an illumination flare (2-minute cooldown)

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

- [veafCombatZone](veafCombatZone.en.md) — for persistent, replayable zones
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafCasMission` API
