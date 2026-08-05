# FEAT-PORTABLE-PREFABS — circulate reusable mission content between missions and squadrons

Status: ⬜ ready

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §4.

> **This is a design lot, not a port.** One ticket, and it is a decision. The rest cannot be
> specified before it, and pretending otherwise would produce tickets nobody can implement.

## The idea worth having

A **prefab** bundles a selection of mission content — groups, statics, zones, F10 drawings, triggers,
warehouses, base64-embedded media, **and the list of mods it depends on** — and re-instantiates it
elsewhere with an anchor, a rotation and a country. "My FARP with its defences, its logistics zone and
its map drawing" becomes one portable object you drop on another map, facing another way, for another
coalition.

The **distribution** half is the better half of their design: a remote `index.json` manifest, fetched
over HTTPS **non-blocking** (a coroutine pumped by the UI tick, so nothing freezes), a disk cache,
data-only validation of everything that comes down, and an explicit warning when a prefab needs a mod
you do not have. That last point is what makes squadron-to-squadron sharing survivable — without it
you instantiate a prefab and get broken units with no explanation.

## Why VMCT wants this and does not already have it

The MCP domain composites — `create_combat_zone`, `create_qra`, `create_cap_mission` — are already
this idea, but **code-shaped**: a developer writes them, they take parameters, and adding one costs a
lot. A prefab is **data-shaped**: a mission maker selects, saves, shares. Different production model,
complementary rather than redundant, and it scales with the community instead of with our dev time.

Cousin of `ENRICH-DEFAULT-PRESETS`, whose problem is that the shipped default `presets.yaml` defines
only three entries. Prefabs are the general answer to "how does content circulate", of which presets
are one kind.

## The blocker, and it is structural

Their prefabs live in `tools/me-mod/` — a **DCS Mission Editor extension**, ~36 700 lines. Two
independent reasons we cannot follow:

1. **`tools/` is GPL v3.** VMCT is permissive. Nothing under it can be copied; the design specs can be
   read and the ideas rewritten, which is the discipline the whole dcs-sms study runs on.
2. **We rejected the live editor.** [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md)
   closed that on measurements, not taste. So "select things in the editor" — their entire front end —
   is not available to us, and reopening it is not on the table.

So the concept and the distribution design transfer; **the way a mission maker picks what goes into a
prefab has to be invented.** That is a real design question, not a detail, and it decides everything
downstream: the format, where instantiation happens, whether this is a `veaf-tools` command, an MCP
action, or a `mission.yaml` section.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Decide the entry point, and write the ADR](tickets/01-decide-the-entry-point.md) | ⬜ |
| — | Format + instantiation, and manifest distribution — **cannot be specified before 01** | — |

## Definition of Done for the lot as it stands

Ticket 01 produces an ADR that either names the entry point and unblocks real tickets, or records
that the idea does not survive contact with our constraints. **Both are acceptable outcomes** — the
second saves the next person from re-reading 36 700 lines of GPL Lua to reach the same conclusion, the
way [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md) did for the editor bridge.
