# FEAT-ROLE-TRAINING-VARIANTS — Training versions of a mission, one per role, built with it

Status: ✅ done · archived 2026-11-24

David, 2026-11-03: shorten mission nights by letting pilots train **before** the night, on the same setting, without learning in advance what the briefing does not announce.
Written up the same day, after an inventory of the MCP (6.35.0) and of the build.

## The need

From a mission night's folder, the build also produces training versions of it:

- one per role — **A2G**, **CAP**, **SEAD** — each in the state "the other roles have done their job";
- one **common** version, every element active, for training together;
- the night's mission itself, unchanged, and the **same briefing** for all of them.

The setting is the night's: theatre, date and time, weather and wind, scripted events, flight plans and player flights.
What the briefing **states** (type and number: "4 tanks covered by an SA-8") stays as placed.
What it describes **vaguely** ("medium-range defences around the SA-6", "an armoured column") is drawn again at **every launch** of a training version — type, number and position within a coherent area — so training does not reveal the night's exact layout.

## What exists — measured 2026-11-03

- **Several `.miz` from one folder**: `build_variants:` and `profiles:` in `mission.yaml` (`veaf_tools/commands/build.py:100`, `veaf_libs/build_profiles.py`) build one `.miz` per profile, suffixed with its name; `modules.COMBATZONE.zone_edits` edits a combat zone per profile (FIX-MARTEAU-PLAY-FINDINGS 06).
  A profile changes the **configuration only**: nothing removes a group of `src/mission`.
- **Drawing at launch**: in a combat zone, the unit-name markers `#spawngroup` (a pool), `#spawncount=1-2`, `#spawnchance` and `#spawnradius=500-2000` draw which elements spawn and where; the `#command` shortcuts `-samSR`, `-samLR`, `-armor`, `-convoy`… also draw the type and size.
- **Real groups, not only commands**: a combat zone captures the Mission Editor groups whose name starts with its own and that stand inside it (`VeafCombatZone:initialize`, `veafCombatZone.lua:1421`), reads the markers in their unit names, and re-integrates a fixed SAM into Skynet when it respawns (`veafSkynet.integrateMissionSpawn`, line 1944).
- **The build already injects groups** into the mission table: `mission_builder/coalition_placeholder.py`, on `mission_tools.group_insertion`.
- **Checked 2026-11-03 (ticket 05)**: draws differ at every launch; `math.randomseed` does not exist in a mission. Before: `veaf.lua:5589` reseeds `math.random` with `os.time()` only when `os` is reachable. On a sanitised server it is not, and whether DCS then starts every launch on the same seed is not measured (ticket 05).

## What the lot delivers

1. **A `training:` block in `mission.yaml`** (ticket 01), the single source of truth: each element's kind (`enemy_cap`, `qra`, `sam_lr`, `a2g_target`, `sam_threat`) and each vague element's draw.
   An element that is not declared stays in every version.
2. **A profile key `remove_groups`** (ticket 02): the build removes Mission Editor groups by name or pattern, whatever they are — placed by hand, a `#veafInterpreter` command, a combat zone's group.
3. **The four training versions** (ticket 03), built alongside the night's mission, by the rules below.
4. **The draws, injected at build** (ticket 04) into the training versions only, from three kinds of candidates: a VEAF command, a group of the night **adopted** as it is, a group the build creates from DCS types.
5. **A draw that differs at every launch** (ticket 05), measured in DCS on a sanitised server, and fixed in Lua if it does not.
6. **The MCP side** (ticket 06): `propose_training_plan` drafts the classification, `set_training_plan` writes it, and the mission prompts tell Claude how to read the briefing to sort stated from vague.
7. **Documentation, changelog, known limitations, demo step** (ticket 07).

### The rules per version

| Kind | Night | `_TRAINING_A2G` | `_TRAINING_CAP` | `_TRAINING_SEAD` | `_TRAINING_ALL` |
|---|---|---|---|---|---|
| `enemy_cap` (AI flights, on-demand CAP) | ✓ | ✗ | ✓ | ✗ | ✓ |
| `qra` | ✓ | ✗ | ✓ forced on | ✗ | ✓ |
| `sam_lr` | ✓ | ✗ | ✓ | ✓ | ✓ |
| `a2g_target` | ✓ | ✓ | ✗ | ✗ | ✓ |
| `sam_threat` (threatens an A2G area, or SEAD secondary objective) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Vague elements | as placed | drawn, by the rules of their kind (D9) | same | same | drawn |
| Not declared | ✓ | ✓ | ✓ | ✓ | ✓ |

### The `training:` block — shape

```yaml
training:
  elements:
    - groups: ["Red CAP Maykop*"]
      kind: enemy_cap
    - qra: QRA-Maykop
      kind: qra
    - groups: ["SA-10 Gudauta"]
      kind: sam_lr
    - zone: Factory
      kind: a2g_target
    - groups: ["Factory-SA-6"]
      kind: sam_threat
  randomize:
    - name: factory-def
      replaces: ["Factory-SA-8 *"]
      pool:
        - group: "Factory-SA-8 #1"
        - command: -sa15
        - units: [{type: "Strela-10M3", count: 2}]
      count: 1-2
      radius: 500-2000
```

The exact keys are ticket 01's to settle; this is the shape agreed on 2026-11-03.

## Decisions — 2026-11-03

| # | Question | Decision |
|---|---|---|
| D1 | Where the draws live | **Injected at build** into the training versions (David). The night's `.miz` carries no trace of training by construction, the draw follows the groups it replaces when they move, and everything is described in `mission.yaml`. Rejected: a dormant combat zone written in `src/mission`, which puts training groups in the night's mission and two sources to keep aligned |
| D2 | The night's mission | Unchanged: vague elements stay as placed; only the training versions draw them. Drawing in the night's mission too would contradict "distinct from the definitive mission" |
| D3 | How elements are classified | Declared in `training:`, drafted by `propose_training_plan` (ticket 06) and reviewed. A naming convention in group names was rejected (invisible without reading every name, names already carry several conventions); a fully automatic sort is impossible for stated vs vague, which depends on the briefing's text |
| D4 | Enemy CAP in the SEAD version | Removed, symmetrical with A2G: "the friendly CAP has done its job" (confirmed by David, 2026-11-03) |
| D7 | Air defences in the CAP version | **Every** air defence stays, declared or not, even inside an `a2g_target` zone or declared `a2g_target` itself (David, 2026-11-03: "pour la version CAP il faut garder les SAM"). SEAD keeps the declared ones only |
| D9 | What a draw is | A draw follows the rules of what it draws: its `kind:`, else the kind of the combat zone it lives in, else kept everywhere; a draw replacing only air defences is a `sam_threat`. Found building *Marteau du Golan*: the vague armour of Khan Arnabah and Sa'sa' stayed in the CAP and SEAD versions |
| D8 | The demo-mission step | Dropped (David, 2026-11-03): training versions are not something a demo mission can show |
| D5 | "Activate the QRA" in the CAP version | The night's QRA definitions are forced on; a night with no QRA gets none invented, and the build warns |
| D6 | Hand-placed groups that must be drawn | **Adopted** (David): renamed under the injected zone in the training version, with the markers added to their unit names. A group **referenced** elsewhere by its name — a Mission Editor trigger, a `mission.yaml` module, an embedded script — is refused with an error naming the reference: renaming it would break that reference without a word. Rejected: a combat zone taking an explicit list of groups instead of the prefix rule, a Lua change to every combat zone for a marginal case |

## Out of scope

- Crossing training with an existing `build_variants:` (MODERN/COLD_WAR × roles): the build refuses the combination with a clear message.
- A bare `.miz` with no mission folder: convert it first (`convert-v5`, or a scaffold).
- Changing the briefing per version: it is common to all, by the need's own terms.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [The `training:` block and its validation](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |
| 02 | [A profile removes Mission Editor groups](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |
| 03 | [The four training versions, built with the night's](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |
| 04 | [Draws injected at build](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |
| 05 | [A different draw at every launch](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |
| 06 | [MCP: propose and write the training plan](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |
| 07 | [Documentation, changelog, limitations, demo](FEAT-ROLE-TRAINING-VARIANTS.md) | ✅ |

## Tickets, in full

## 01 — The `training:` block and its validation

Status: ✅ done

A `training:` block in `mission.yaml`, read by the build and checked by `validate_mission`, in the shape the PRD gives.

- `elements[]`: one selector — `groups` (names or `*` patterns on Mission Editor group names), `zone` (a combat zone's `zone_name`), `qra` (a QRA definition's name), `cap_mission` (an on-demand CAP's name) — and a `kind` among `enemy_cap`, `qra`, `sam_lr`, `a2g_target`, `sam_threat`.
- `randomize[]`: a `name`, `replaces` (patterns of the groups the draw stands in for), a `pool` of candidates — `group:` (a Mission Editor group), `command:` (a VEAF `#command` shortcut), `units:` (DCS types and counts) — and `count` and `radius`, each a number or a `min-max` range.
- An optional `at:` on a draw anchors it on a point instead of the replaced groups' positions.

### Done when

- The block parses into a typed model (`models.py` of the worker that owns it), with Google docstrings and full annotations.
- `validate_mission` reports, as errors naming the culprit: a selector matching nothing, an unknown zone, QRA or CAP mission, an unknown `kind`, a group claimed by two kinds, an unknown `command:` alias, an unknown DCS type in `units:`, a `count` larger than the pool, a malformed range.
- A group both in `elements` and in a `randomize.replaces` is an error: a vague element is drawn, not classified.
- The shipped `src/defaults/mission-folder/mission.yaml` carries the block commented out, with one line per key (CLAUDE.md §9, defaults lockstep).
- Tests cover every error above, each with a case that passes and one that fails.

## 02 — A profile removes Mission Editor groups

Status: ✅ done

A profile only changes configuration today (`veaf_libs/build_profiles.py`): no profile can take an AI flight placed in the Mission Editor, or a SAM placed by hand, out of its `.miz`.
This ticket adds a generic profile key, `remove_groups:` (names or `*` patterns), applied by the build to the mission table of that profile's `.miz`.
Ticket 03 uses it; it stands on its own for any profile.

### Done when

- A profile with `remove_groups: ["SA-10 *"]` builds a `.miz` without those groups, whatever their category (vehicle, plane, helicopter, ship, static) or their form (placed by hand, `#veafInterpreter` unit, combat zone group).
- A pattern that matches nothing is a build warning naming the profile and the pattern.
- A country left with no unit is handled as `coalition_placeholder` handles it: DCS purges an empty country on save.
- The build without a profile is byte-identical to the same build before the lot (test on a fixture mission).
- Tests assert on the built mission table, not on the profile mapping.

## 03 — The four training versions, built with the night's

Status: ✅ done

When `mission.yaml` holds a `training:` block, `veaf-tools build` produces the night's `<mission>.miz` and four more: `_TRAINING_A2G`, `_TRAINING_CAP`, `_TRAINING_SEAD`, `_TRAINING_ALL`.
Each is a profile **derived** from the block at build time — never written into `mission.yaml` — applying the PRD's rule table with ticket 02's `remove_groups`, `zone_edits` and the QRA and CAP modules' settings.

### Done when

- One parametrised test sweeps the whole rule table: every `kind` × every version, presence and absence checked in the built `.miz` (groups in the mission table, combat zones, QRA definitions and on-demand CAPs in the generated configuration).
- `a2g_target` on a combat zone removes the zone's groups from the CAP and SEAD versions, not only its activation.
  **Changed while building (2026-11-03)**: the zone's configuration and radio menu are kept. A `sam_threat` placed in the zone is captured by it and spawns only when it activates; taking the zone out would have taken the SAMs the CAP and SEAD versions keep.
- The CAP version forces the night's QRA definitions on; a mission with no QRA builds the CAP version with a warning saying none exists.
- The briefing texts and pictures are identical in the five `.miz` (test).
- The night's `.miz` is byte-identical to the same folder built without the `training:` block.
- A `training:` block next to `build_variants:` is refused with a message naming both keys (PRD, out of scope).
- `build_mission` (MCP) reports the five paths.

## 04 — Draws injected at build

Status: ✅ done

In the training versions only, each `randomize` entry becomes a combat zone injected into the mission table, so the existing combat-zone machinery draws at every launch (PRD, D1 and D6).

For each entry, the build:

1. removes the `replaces` groups from their fixed place;
2. places a trigger zone `TRAINING-<name>` centred on them (or on `at:`), large enough for `radius`;
3. fills it with the pool's candidates, all in one `#spawngroup`, with `#spawncount` = `count` and `#spawnradius` = `radius` in their unit names:
   - `command:` — a fake unit carrying `#command="<alias>"`;
   - `group:` — the Mission Editor group **adopted**: renamed under the zone's prefix, markers added to its unit names, everything else kept (type, units, loadout, skill);
   - `units:` — a real group the build creates from the DCS types, with `mission_tools.group_insertion`;
4. declares the zone in the generated configuration: active at start, no radio menu, no activation by players.

If the vague group is already in one of the night's combat zones, no zone is injected: the markers are added to the existing zone's units, in the training version.

### Done when

- On a fixture mission with **no VEAF command at all**, the training version draws among its own groups: the adopted groups are in the injected zone, with the markers, and the fixed ones are gone.
- Each kind of candidate has its test on the built mission table.
- A `group:` candidate referenced by name in a Mission Editor trigger, in `mission.yaml` (QRA, Skynet, a module's settings) or in an embedded script makes the build **fail**, with a message naming the group and the reference (D6).
- The night's `.miz` holds no `TRAINING-` zone and no marker added by the build.
- A Lua test runs the generated configuration against the DCS mocks and checks the zone spawns `count` elements from the pool, within `radius`.
- An injected SAM is integrated into Skynet when it spawns (Lua test on the mocks, through `veafSkynet.integrateMissionSpawn`).

## 05 — A different draw at every launch

Status: ✅ done

The whole point of the draws is that two launches differ.
`veaf.lua` (initialisation, around line 5589) reseeds `math.random` with `os.time()` only when `os` is reachable, directly or through `SERVER_CONFIG.getModule("os")`.
On a sanitised server neither is, and nothing says whether DCS then starts each launch on the same sequence.
Not measured.

### Done when

- Measured in DCS, on a sanitised `MissionScripting.lua`: the first ten `math.random(1000)` values of two launches of the same mission, logged by a test script; the result, with its date, goes into `known-limitations.yaml` (`kind: dcs`) whichever way it falls.
- If the two sequences are equal: the reseed falls back on a source that varies between launches without `os` — a candidate is `timer.getRealTime()`, to be measured as well — with a Lua test showing the fallback is taken when `os` is absent.
- If they differ: nothing changes in Lua, and the measurement is what closes the ticket.
- The DCS part is an entry in `DCS-SESSION-TODO.md` with the exact steps, since it needs the game.

### Measured — 2026-11-03

On DAVID-BUREAU, a copy of *Marteau du Golan* with a `training:` block, `_TRAINING_ALL.miz` launched three times in one DCS session, with a `veaf.seedRandom` written for the measure that logged its source and the first draw:

| Launch | Seed source | First `math.random(1000000)` | Sa'sa' drew |
|---|---|---|---|
| 1 | `nil` | 256387 | the drawn `-armor`, `Sasa-bmp`, `Sasa-t72` |
| 2 | `nil` | 586566 | `Sasa-t72`, `Sasa-armor-1`, the drawn `-armor` |
| 3 | `nil` | 119054 | — (the simulation never ran) |

`os` was reachable (`MissionScripting.lua` keeps it), so the `nil` can only come from the `math.randomseed` guard: the function does not exist in the mission environment, and the 2021 guard in `veaf.lua` has never seeded anything.
The draws differ anyway: DCS's own sequence changes from one launch to the next.
So **no Lua change**: the measuring function was removed, and the measure went into `known-limitations.yaml` (`math-randomseed-is-not-in-the-mission-environment`).

## 06 — MCP: propose and write the training plan

Status: ✅ done

Two actions, so that "build the training versions too" works on a mission Claude has just made as on an existing one.

- `propose_training_plan(mission_path)` — a **draft** `training:` block, from what the data can tell: AI fighter flights of the enemy coalition and on-demand CAPs → `enemy_cap`; QRA definitions → `qra`; long-range SAM types from the units database → `sam_lr`; combat zones → `a2g_target`; other SAMs inside or near an A2G zone → `sam_threat`.
  Everything is proposed **as placed**: only the briefing can say what is vague, and the action does not read prose.
  Each proposal says why it was made (the type, the module), so the reviewer can overrule it.
- `set_training_plan(mission_path, training)` — writes the block into `mission.yaml`, comments preserved, backed up first, refused when ticket 01's validation fails.

Both are thin handlers over the worker of ticket 01 (CLAUDE.md, layers): no CLI command, since a mission maker without an AI writes the block by hand.

### Done when

- On a fixture mission, the draft classifies an enemy CAP flight, a QRA, an SA-10, a combat zone and the SA-6 protecting it as the PRD's table expects.
- `set_training_plan` round-trips: what it writes, `validate_mission` accepts and the build turns into the five `.miz`.
- The mission prompts (`new-objective-mission.*.md`, and the authoring guide) tell Claude, once the briefing is written: offer the training versions; call `propose_training_plan`; for each element the briefing describes vaguely, move it to `randomize` with a pool of the same role (an SA-8 among short-range SAMs, a tank among armour); show the user the plan before writing it.
- The action catalogue documentation is updated in the same change (MCP catalogue lockstep).

## 07 — Documentation, changelog, limitations, demo

Status: ✅ done

### Done when

- A FR/EN page for mission makers — what the training versions are, how to write the `training:` block, the rule table, how a vague element is drawn, what is refused and why — in the `mkdocs.yml` `nav` with its `nav_translations`, and `MISSION_YAML_REFERENCE` (FR/EN) documents `training:` and `remove_groups`.
- The support bot's page index is refreshed (`services/support-bot`, `refresh_doc_pages.py`).
- `poetry run docs-check` is green.
- `CHANGELOG.md` has one entry under `[Unreleased]`, at the end of the section.
- `known-limitations.yaml` carries what the lot leaves (training with `build_variants:`, a referenced group cannot be drawn) and ticket 05's measurement; `dcs-runtime-traps.md` is regenerated.
- ~~A step in `VEAF/VEAF-Demo-Mission-v6`~~ — **dropped** (David, 2026-11-03): not something a demo mission can show (PRD, D8).
