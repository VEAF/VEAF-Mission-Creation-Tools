# CHORE-GITHUB-ISSUE-TRIAGE — re-read the 63 open GitHub issues against v6

Status: ✅ done — 2026-08-17. Labelled first, then closed with David issue by issue: **63 open → 46**.
The `probably-done` label is now empty; `still-valid` and `verify` remain as the standing triage.

Date of the re-read: 2026-08-17. Origin: David, "faisons le ménage dans les issues sur GitHub".

## The situation the numbers describe

63 issues open, and the tracker of record has been `.backlog/` since ADR 0009:

| Nature | Count |
|--------|-------|
| Opened 2020-2023 — the v5 framework | 49 |
| 2024-2025 | 10 |
| 2026, live work (#722, #723, #725) | 3 |
| Drift robot (#618), left alone | 1 |

So **78 %** of the open issues describe a framework that has since been rewritten. Some of them
were *fixed years ago* and nobody went back to close them: the issue list has stopped saying
anything about what is left to do, which is the actual defect this lot addresses.

## Why nothing is closed

David's arbitration: **label, do not close**. Two reasons hold it up.

- A third of these reports come from other people — Sharko, Tripack, RexAttaque, MacFlorent,
  kaltokri, mitch10593, The-Reaper. Closing someone's report on the strength of a grep is how a
  contributor learns not to file the next one.
- `probably-done` is a *finding*, not a fact. Each one below cites what was measured, and a
  couple are only partly true (#39, #67, #72 are marked as such). The confirmation belongs to
  whoever knows the feature.

Nothing was commented on the issues either — the evidence lives here rather than in 62 public
comments.

One exception is not a finding at all: **#299** is closed in substance, and says so in the
repository — `.backlog/archive/FIX-QRA-DYNSLOT-CATEGORY.md` names it as the issue it fixes. That
cross-reference was searched for across the whole backlog and the whole git history: **#299 is the
only open issue any lot or commit claims to fix**, which is why the other thirteen verdicts rest on
reading the current code instead.

## The label vocabulary

Defined for contributors in [`CONTRIBUTING.md`](../../CONTRIBUTING.md#issue-intake).

| Label | Applied to | Meaning |
|-------|-----------|---------|
| `v5-era` | 49 | Opened before v6; re-read it in the v6 context first |
| `probably-done` | 14 | v6 appears to do this already — evidence below |
| `still-valid` | 32 | Re-read: really missing, need still holds |
| `verify` | 16 | Not settleable from the code; needs a reproduction, usually in DCS |

`v5-era` is orthogonal — it says *when*, the other three say *what*. #618 (the vendored-drift
robot) keeps its own label and was not touched.

## `probably-done` — the evidence, issue by issue

| Issue | What it asked | What v6 has |
|-------|---------------|-------------|
| #148 | Combat-zone radio menu is not paginated | `veafRadio` paginates **automatically at render time** — `MENU_PAGE_SIZE = 10` in the menu builder (ADR 0013), so the issue's "refactor the whole Radio feature to auto-paginate" is what happened, generically, rather than in the module it named. One documented exception: a node carrying a `USAGE_ForUnit` command **opts out** (`veafRadio.lua:398-401`), because one logical command becomes one DCS entry per callsign and no global page split can bound it — worth a look before closing |
| #152 | A module exporting the map data as `.json` | `veaf-tools export` ships JSON/YAML/Markdown (`FEAT-EXPORT-MISSION`, `FEAT-EXPORT-BFR-PARSER`) |
| #162 | Set a fixed date in the weather injector | `date:` accepts `2024-03-15`, `today`, `+1` — `weather_injector/models/configuration.py:22` |
| #226 | Test `world.removeJunk` | Called in production: `veafCombatZone.lua:1246`; the feature issue #271 is closed |
| #233 | Functions for a user radio menu | F10 menus are declared in `mission.yaml` (`FEAT-RADIO-YAML-MENUS`, ADR 0011) |
| #86 | An example of how to build a radio menu | Same: the YAML declaration replaced the hand-written example |
| #294 | Redo security: drop `/secu login`, role-based menus | `REVIEW-SECURITY-LAYER` did exactly that — `veafCommands.lua:78-79` states there is no global login any more; tiers live in `veafSecurity.lua` |
| #295 | Update the unit list since 2.9.19.13478 | Currenthill / Oplot / Iskander are in `veaf_libs/data/dcsUnits.yaml` and `dcsUnits.lua`, fed by `update-dcs-data` |
| #299 | Dynamic aircraft slots do not trigger QRA | **Not a finding but a fact**: `.backlog/archive/FIX-QRA-DYNSLOT-CATEGORY.md` opens with *"Fixes #299 (reported by Tripack)"* and is ✅ — the root cause was `veafEventHandler.completeUnitFromName` reading the wrong category. The odd `setReactOnHelicopters` symptom is answered too (`veafQraCore.lua:486` now respects an explicit value). The lot simply never closed the issue |
| #57 | Spawn an artillery group that fires on a position | **Partly, and the verdict was corrected on 2026-08-17**: `veafGroundAI` fires (`FireAtPoint`, `:568`) but **spawns nothing** — grepped, it holds no `spawnGroup`, no `veafSpawn.` call. The issue asks for a spawn *coupled to* the fire order, and only the second half exists. Downgraded from a clean verdict when David asked for the evidence line by line |
| #206 | Make a group fire through `-shell` | Same module: the order spec at `veafGroundAI.lua:364-372` targets a named group |
| #39 | Test whether smoke and **fires** can be spawned | **Partly**: `veafSpawn.spawnSmoke` exists (`veafSpawnEffects.lua:282`); fires were not found |
| #67 | Use polygon zones for combat zones | **Partly**: `veafCombatZone` handles a polygon trigger zone, but only **type 2**, and its `if/elseif` has no `else` — any other type silently finds no units (measured in `FEAT-MCP-MUTATION-ACTIONS`) |
| #72 | F10 drawings + sanctuary from polygon trigger zones | **Partly**: `veafSanctuary` takes `polygon_units` (a group name works since `MIGRATE-DEMO-MISSION-V6`); drawings are authored through the MCP (`add_map_drawing`) |

## `still-valid` — checked absent

Grep-level absences worth recording, because they are the ones a reader would assume were done:

- **#296** (new units in the platoon spawner) — the units *are* in `dcsUnits`, but a platoon's
  composition is a **hand-written table** in `veafCasMission.lua` (the armour tiers at `:264-273`,
  `"MBT Leopard 1A3"`, `"Merkava_Mk4"`…), and `Oplot`, `T-90M` and `Terminator` appear in none of
  them. #295 is done and #296 is not — same request, two surfaces, and the second one does not
  benefit from the data pipeline at all.
- **#88** (QRA tied to an airbase) — no `setBase`, no `S_EVENT_BASE_CAPTURED` in `veafQraCore.lua`.
- **#185, #186, #182, #183, #176, #179** (AirWaves) — `veafAirWaves.lua` exists and is 59 KB, and
  contains **no mention of QRA** at all, so #185 ("replace the QRA module") never started.
- **#33** (refuse a malformed option) — `veafSpawnParser.lua` has no unknown-option path.
- **#25, #123** (randomisable / hidden-and-late-activated interpreter units) — neither
  `randomiz`, `hidden` nor `lateActivation` occurs in `veafInterpreter.lua`.
- **#60** (toggle CTLD sling load) — no `sling` toggle in the radio layer.
- **#38** (spawn an FM radio beacon) — `ctld.spawnRadioBeaconUnit` is *mentioned* in
  `veafGrass.lua:1349` as having no public equivalent; there is no VEAF `-beacon`, which also
  leaves **#192** open.
- **#40** (`${METAR}` in the briefing) — the weather injector accepts a METAR *input*; no briefing
  substitution variable exists.

The rest of the `still-valid` set (#301, #284, #259, #248, #189, #188, #187, #178, #177, #153,
#132, #130, #129, #42) are features never implemented, kept because the need reads as valid on v6.
They were not individually grepped — the label says "not delivered and still wanted", which their
titles alone establish; the `verify` set below is where the doubt lives.

**#722, #723, #725** are labelled `still-valid` and are the three that deserve a lot **now**: they
are 2026 findings about `convert-v5` and the `combat_zones:` schema, measured on the campaign
corpus, and no lot covers them.

## `verify` — why the code could not settle it

| Issue | What is there, what is missing |
|-------|-------------------------------|
| #66 | `veafCombatZone` has `delayedSpawners` (`:293`, `:591`) — whether a delayed group now despawns with the zone needs a run |
| #151 | `veafSkynetIadsHelper` adds dynamically spawned groups to a network (`:495-537`); whether a combat-zone SAM reaches it is a DCS question |
| #198 | Artillery orders exist; the **fire-adjustment loop** (`correct 09050`) was not found |
| #289 | `renameUnitsSequentially` exists (`veafCombatZone.lua:1098`); the request is an *option to turn it off* while debugging |
| #164 | `veafSpawnAircraft` mentions `helicopter` five times — enough to doubt the issue, not enough to close it |
| #128 | `USAGE_ForGroup` exists (`veafRadio.lua:31`); the game-master case needs a multiplayer test |
| #175 | `BULLSEYE` appears in the waypoints-injector README and in `veafI18n`, not in injector logic |
| #245, #290, #232, #209, #240, #107, #101, #87, #261 | Behavioural reports — a reproduction decides, not a grep |

## Two operational notes, since both cost a wrong conclusion

- **`gh issue edit` goes through GraphQL**, which spent this session returning intermittent
  `503`s while the REST quota sat untouched at 4735 requests — so the first pass looked like a
  rate limit we had caused, and half its "failures" were issues that had in fact been labelled.
  The labels were applied in the end through `gh api -X POST …/issues/<n>/labels`, one call per
  issue carrying every label it needs. Prefer REST for bulk label work.
- **A label can contain a space** (`help wanted`, `low priority`), which broke the verification
  script's field splitting and made it report 10 missing pairs on 5 issues that were correctly
  labelled. The check was re-run against the label list itself rather than a `cut` of it. Final
  state verified: 63 open, 49 `v5-era`, 14 `probably-done`, 32 `still-valid`, 16 `verify`, exactly
  one verdict per issue and none on #618.

## Definition of done

- [x] Every open issue carries a verdict label, `#618` excepted
- [x] The verdict of each `probably-done` cites what was measured
- [x] The intake rule written where a contributor reads it (`CONTRIBUTING.md`) and where an agent
      reads it (`docs/agents/issue-tracker.md`)
- [x] David confirms and closes the `probably-done` set — **his call, not an agent's**
- [x] #722 / #723 / #725 get their lot, shipped in 6.15.0, and closed
- [x] The 14 `probably-done` confirmed and closed — **and two verdicts were overturned when David asked for
      the evidence line by line**: #57 (`-arty` does spawn a battery, `veafShortcuts.lua:1084`, so only the
      one-gesture coupling is missing — #198's scope) and #72 (`VeafDrawingOnMap` exists at `veaf.lua:4514`
      and `veafSanctuary` draws with it; the first pass had looked at the design-time tooling instead of the
      runtime Lua). Asking for the evidence is what found them, not asking for the conclusion
- [x] What the closures would have buried is kept: `FIX-COMBATZONE-ZONE-TYPE-SILENT` for #67's missing `else`,
      and `SPAWN-FIRES` on the roadmap for #39's fire half, with David's `_bomb` explosions lead — `FIX-CONVERT-V5-SILENT-LOSSES`, opened 2026-08-17 with
      every claim of the three reports re-verified against the code first
