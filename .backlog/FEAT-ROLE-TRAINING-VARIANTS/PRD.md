# FEAT-ROLE-TRAINING-VARIANTS — Training versions of a mission, one per role, built with it

Status: ⬜ ready

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
- **To check**: `veaf.lua:5589` reseeds `math.random` with `os.time()` only when `os` is reachable. On a sanitised server it is not, and whether DCS then starts every launch on the same seed is not measured (ticket 05).

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
| Vague elements | as placed | drawn | drawn | drawn | drawn |
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
| D4 | Enemy CAP in the SEAD version | Removed, symmetrical with A2G: "the friendly CAP has done its job". Recommended default, not yet confirmed by David; one line of the rule table to flip if he decides otherwise |
| D5 | "Activate the QRA" in the CAP version | The night's QRA definitions are forced on; a night with no QRA gets none invented, and the build warns |
| D6 | Hand-placed groups that must be drawn | **Adopted** (David): renamed under the injected zone in the training version, with the markers added to their unit names. A group **referenced** elsewhere by its name — a Mission Editor trigger, a `mission.yaml` module, an embedded script — is refused with an error naming the reference: renaming it would break that reference without a word. Rejected: a combat zone taking an explicit list of groups instead of the prefix rule, a Lua change to every combat zone for a marginal case |

## Out of scope

- Crossing training with an existing `build_variants:` (MODERN/COLD_WAR × roles): the build refuses the combination with a clear message.
- A bare `.miz` with no mission folder: convert it first (`convert-v5`, or a scaffold).
- Changing the briefing per version: it is common to all, by the need's own terms.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [The `training:` block and its validation](tickets/01-training-block-schema.md) | ⬜ |
| 02 | [A profile removes Mission Editor groups](tickets/02-profile-remove-groups.md) | ⬜ |
| 03 | [The four training versions, built with the night's](tickets/03-role-variants.md) | ⬜ |
| 04 | [Draws injected at build](tickets/04-injected-draws.md) | ⬜ |
| 05 | [A different draw at every launch](tickets/05-random-seed-per-launch.md) | ⬜ |
| 06 | [MCP: propose and write the training plan](tickets/06-mcp-training-plan.md) | ⬜ |
| 07 | [Documentation, changelog, limitations, demo](tickets/07-docs-and-demo.md) | ⬜ |
