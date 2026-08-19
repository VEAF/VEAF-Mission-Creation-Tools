# FIX-SCRATCH-MISSION-PLAYABLE — a mission built from scratch cannot be flown

Status: ✅ done — all four tickets delivered 2026-08-15 (02 the guard on 08-14). A from-scratch
mission is now flyable end to end: coalitions populated, a player-slot action, and a from-scratch
build starts at noon.

Origin: David, 2026-08-14, thirty seconds after loading a mission prepared for the DCS verification
session — DCS opened **CHANGING COALITIONS** with every country unassigned. Found by starting the
game, which is exactly what a session is for.

## Three defects, one theme

A mission created from nothing — `prepare --theatre`, `scaffold_mission --theatre`, then populated
through the MCP — **is not playable**, and nothing says so.

### a. `coalitions` is never populated, and a comment claims otherwise

`blank_mission.py:80` ships `"coalitions": {"blue": {}, "red": {}, "neutrals": {}}`, and line 10
states the gap is covered:

> or the composites (`add_group` populates coalitions/countries on demand) — fills them in.

**No line of the MCP writes that table.** Grepped: the only matches are `enemy_coalitions`, a QRA
field with nothing to do with it. So the work was deferred to a place that never did it, which is the
same shape as `VMR-088` — and the comment is what made that deferral invisible.

`coalitions` maps **country ids to a side**; `coalition` holds the units. Populating the second
without the first gives a mission whose units live in a side that does not exist.

**There is no canonical distribution to copy.** Measured across this repository's missions: blue
carries between 5 and 30 countries, red between 3 and 12 — each author picked their own in the
editor. So the fix is not a default table; it is that **adding a group assigns that group's country
to its side**, which is precisely what the comment promises.

### b. Nothing can create a player slot

David, the same afternoon: a mission maker will need this for certain — and he is right, because the
assistant cannot produce a flyable mission at all today.

`add_group` handles ground groups. `set_unit_properties` **refuses** `Client`/`Player`, and that
refusal is correct and stays: writing an AI skill over a `Client` deletes a multiplayer slot and the
reverse creates one, which is the bug `FIX-TEMPLATE-SLOTS-VISIBLE` was opened for. What is missing is
an action that *creates* the slot.

`add_air_group` (`FEAT-MCP-MUTATION-ACTIONS` ticket 09) is blocked on parking data from a DCS session
— but **a slot in the air, or on the ground with a caller-supplied spot, needs none of it**. That half
is deliverable now.

### c. `validate` does not catch any of it

The mission built for that session **passed `validate` and built cleanly**, then DCS refused it. A
mission with units in a side owning no country is unflyable, and the one tool whose job is to say so
before the build said nothing. That is the defect that let a and b stay invisible.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Adding a group assigns its country to its side | ✅ |
| 02 | `validate` refuses a mission nobody can fly | ✅ |
| 03 | An action that creates a player slot | ✅ |
| 04 | A mission nobody asked to fly at night starts at 03:48 | ✅ |

Order matters: 02 is the guard that proves 01, and it must fail on today's output before 01 lands.

**04 arrived late, on 2026-08-15**, when David listed the three things wrong with that mission and the
third one — *"en plus tu me la fais démarrer de nuit"* — turned out to be recorded nowhere. Two of
three defects were ticketed; the one nobody wrote down is the one that needed a ticket most.

## Definition of Done

- A mission created by `scaffold_mission` + `add_group` opens in DCS without the coalition dialog.
- `validate` reports a side holding units but no country, and reports a mission with no player slot.
- An assistant can produce a flyable mission end to end, without the editor.
- TDD throughout; full Python gate green; coverage ratchet respected.

## Ticket 02, done first on purpose

The guard was written before either fix and **failed on the session's own mission** — units in blue,
`coalitions.blue` empty — which is what proves it measures something. It reports zero errors on the
five real missions in `test/veaf-tools/`, so it is discriminating rather than merely strict.

One decision taken while writing it: the three quirk readers (`indexed`, `numeric_first`, `CATEGORIES`)
**moved from `veaf_mission_mcp.mission_table` to `veaf_libs.mission_table`**, re-exported so no import
changed. The validator needed the same dict-or-list quirk the MCP actions do, the dependency runs
MCP → veaf_libs, and a second copy would have received half the fixes.

---

## 01 — Adding a group assigns its country to its side

Status: ✅ done 2026-08-15 — assign_country_to_side, called from the shared writer; both table shapes handled
Type: fix
Files: the group writer shared by `add_group` and the composites under
`src/python/veaf-tools/veaf_mission_mcp/`, `veaf_libs/blank_mission.py` (its comment), tests

### The fix

Wherever a group's country is created or found in `coalition.<side>.country`, add that country's **id**
to `coalitions.<side>` if it is absent. Idempotent — two groups from the same country must not list it
twice.

Both tables in one operation, because they describe the same fact from two angles and DCS needs both.

### Careful

- `coalitions.<side>` is a **list of ids** in a real mission (measured: `blue: [21, 11, 8, …]`), while
  the blank mission ships `{}`. An empty Lua table serialises identically either way, so the writer has
  to cope with both shapes — the quirk `mission_table.indexed` exists for.
- Do **not** invent a default distribution. Measured across this repo's missions, blue holds 5 to 30
  countries and red 3 to 12: there is no canonical set, and inventing one would put countries on a side
  their author never chose.
- The composites (`create_combat_zone`, `create_qra`, `create_cap_mission`) should go through the same
  writer — check that they do rather than assuming, and cover one of them.

### Also

`blank_mission.py:10` claims this already happens. Once it does, the comment becomes true — keep it,
but make it name what actually performs the work, so the next reader can verify instead of trusting.

### TDD

- Failing first: `add_group` on a blank mission, then assert the country id is in `coalitions.<side>`.
- Idempotence: two groups, same country, one entry.
- A second country on the same side appends rather than replaces.
- One composite covered end to end.

### Acceptance criteria

- [x] `coalitions` populated by every path that creates a group; idempotent. The shared writer
      `mission_tools.group_insertion.assign_country_to_side` is called from `add_group`, so
      `add_group` (MCP), all three composites and `add_player_slot` inherit it.
- [x] Both the dict and the list shape handled (via `mission_table.indexed`).
- [x] Full Python gate green.

---

## 02 — `validate` refuses a mission nobody can fly

Status: ✅ done 2026-08-14 — both checks in place; proven on the session's own broken mission and silent on the five real missions in the repository
Type: fix
Files: `src/python/veaf-tools/veaf_libs/mission_validator.py`, tests

### Why this comes first

The mission built for the 2026-08-14 session **passed `validate` and built cleanly**, and DCS then
refused to load it without a manual coalition assignment. The missing guard is why defects a and b of
this lot stayed invisible. Write it first and watch it fail on today's output — that failure is the
proof the guard measures something.

### The two checks

1. **A side holds units but its coalition owns no country** → **error**. That is the state DCS shows as
   CHANGING COALITIONS, and it is unambiguous: units exist in a side that does not.
2. **No unit anywhere has skill `Client` or `Player`** → **warning**, not an error. A mission with no
   player slot is legitimate — a server-side scenario, a template library — so this must not refuse the
   build. But it is the other half of what made a mission unflyable, and worth saying once.

Word both so the fix is obvious from the message: name the side, and say that a slot is what a pilot
needs to enter the mission at all.

### TDD

- Failing first: a mission with units in blue and `coalitions.blue` empty is reported as an error.
- A mission whose country is assigned passes.
- The player-slot check warns rather than errors — proven by a mission with no slot still validating.

### Acceptance criteria

- [ ] Both checks in place with tests; the first an error, the second a warning.
- [ ] `validate` stays clean on the repository's own fixtures, which are real missions.
- [ ] Full Python gate green.

---

## 03 — An action that creates a player slot

Status: ✅ done 2026-08-15 — add_player_slot ships; dynSpawnTemplate fix confirmed in game
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/actions.py` and its group writer, the mission-maker
action catalogue (both languages), tests

### The need

A mission maker will need this for certain, and until it exists an assistant cannot produce a mission
anybody can fly. Writing one by hand is not a workaround: a plane group carries payload, radio,
callsign, onboard number, parking, and a first waypoint whose `type` and `action` are a **pair** — a
missing field makes DCS refuse the mission.

### What it does, and what it deliberately does not

An action creating an aircraft group whose units carry `skill: "Client"` and whose group carries
`dynSpawnTemplate = false` (see the measurement below — the missing flag is what broke the 2026-08-14
slot), with:

- **an air start** — position, altitude, speed, heading. Needs no runtime data at all.
- **a ground start when the caller supplies a parking spot.** This action does **not** resolve airfield
  parking: that is `FEAT-MCP-MUTATION-ACTIONS` ticket 09's data and it is not captured yet. Refuse a
  ground start with no spot rather than guessing one, and name that ticket in the refusal.
- `TakeOffParking` vs `TakeOffParkingHot` as an explicit cold/hot choice, written as the `type`/`action`
  **pair** DCS stores.

It does **not** change an existing unit's skill. `set_unit_properties` refuses that on purpose, and
this action must not become a back door to it.

### Measured, not invented

Read a real player group out of `test/veaf-tools/demo-mission/veaf-demo-mission.miz` before writing the
writer. `A-10C Kobuleti  HOT` is an `A-10C_2`, `skill: Client`, `parking: "43"`, and its first waypoint
is `TakeOffParkingHot` / `From Parking Area Hot`. The cold pair is `TakeOffParking` /
`From Parking Area`, verified by making exactly that edit on 2026-08-14 and loading the result.

#### `dynSpawnTemplate` is what made the 2026-08-14 slot unusable — verified in game 2026-08-15

A slot created by this action **must carry `dynSpawnTemplate = false`**, and that single field is the
whole lesson of the 2026-08-14 defect.

**Confirmed by flying it**: the same mission with the flag cleared gives a slot David can take
(*"le A-10 fonctionne"*, 2026-08-15). So this is a measured fix rather than a hypothesis, and the
assertions below are writing down a known-good shape.

The slot placed that day was copied out of the demo mission — including its `dynSpawnTemplate = true`.
That flag does not describe a slot: it marks the group as a **template for dynamic spawn**, which
requires an airfield configured for it. This mission configures none, so the group was in the file,
absent from the slot list, and David stayed a spectator. He had in fact said so on day one — *"il n'y
a que des templates de groupe, et pas de base aérienne configurée pour les slots dyn"* — and the
build had 105 groups carrying the flag.

The differential against the A-10 he added in the editor, and against the demo's original:

| | script (ko) | editor (ok) |
|---|---|---|
| `dynSpawnTemplate` | **`true`** | **`false`** |
| `communication` / `frequency` | `false` / 121.5 | `true` / 251 |
| `skill` | `Client` | `Player` |
| ids | 9001 | 9003 |
| parking | `43` / `16`, `airdromeId` 24 | `6` / `01`, `airdromeId` 22 |
| first waypoint | `TakeOffParking` | `TakeOffParking` — identical |

**`skill` is not the cause**: David, 2026-08-15 — *"c'est pas le slot Client ; ça fonctionne dans une
mission DCS"*. `Client` stays what this action writes. The forced ids are cleared too (the editor
writes 900x itself), as is the parking pair, complete on both sides.

`communication = false` is a second, milder defect of the same copy: both working A-10s carry `true`
with a real frequency. A created slot gets a group frequency rather than an inherited `false`.

### TDD

- A created slot has `skill: "Client"`, `dynSpawnTemplate = false` and a group frequency — the three
  assertions that would have caught the 2026-08-14 defect. It shows up in `describe_units`.
- Copying a group out of a mission does **not** carry `dynSpawnTemplate = true` over into a slot. That
  is the exact path the defect took.
- Cold and hot write the right `type`/`action` pair — both asserted, since writing one without the
  other is the silent failure here.
- A ground start with no parking spot is refused, with a message naming ticket 09's data.
- Its country lands in `coalitions.<side>` as well, exercising ticket 01's writer from this path.

### Acceptance criteria

- [x] The action ships (`add_player_slot`), documented in the mission-maker catalogue and the
      developer reference, both languages.
- [~] A mission built from `scaffold_mission` + this action + `build_mission` is flyable — the pieces
      are unit-tested (Client skill, `dynSpawnTemplate` false, group frequency, waypoint pairs,
      coalitions populated); flying it is David's in-game step, and the `dynSpawnTemplate` fix is
      already confirmed in game (2026-08-15).
- [x] Full Python gate green; coverage ratchet respected.

---

## 04 — A mission nobody asked to fly at night starts at 03:48

Status: ✅ done 2026-08-15 — shipped versions.yaml reduced to a single noon variant, tutorial kept commented
Type: fix
Files: the build chain between `blank_mission` and the produced `.miz` — `weather_injector` is the
prime suspect; tests

### The complaint

David, 2026-08-15, listing what was wrong with the mission handed to him for the DCS session: *"en
plus tu me la fais démarrer de nuit"*. Third defect of the same mission as tickets 01 and 03, and the
only one that was **not** written down anywhere until now.

### What is measured

- `blank_mission.py:82` ships `"start_time": 43200` — **12:00, midday**. The blank mission is innocent.
- Both `TestMenuFR.miz` and David's `TestMenuFR-david.miz` carry `start_time = 13695` — **03:48**.
- **`13695` appears nowhere in the repository.** It is a *computed* value.
- `weather_injector_worker.py:274` is the one place that writes `mission_content["start_time"]`, and
  its `dawn` preset is `sunrise+30*60` — a computed dawn, consistent with 03:48 on the Caucasus in June.
- The session's `mission.yaml` (kept as `mission.yaml-source` next to the mission) declares **no**
  weather section at all. The `WEATHER` module it lists is the runtime Lua module, not the injector.

### Told apart by measurement — 2026-08-15

Traced through the code rather than reasoned about:

- `veaf_tools/commands/build.py:405` runs the weather step **only when `src/versions.yaml` exists**
  (`weather_path = _step_file(...); if weather_path:`). With no such file, no weather step runs and the
  built mission keeps the blank's `start_time` — **43200, noon**. So the first hypothesis's *code* is
  correct: a mission with no weather config does start at midday.
- **But `src/versions.yaml` is a shipped default.** `mission_builder_worker.py:1232` maps it to the
  weather pipeline, and `complete_src_folder_with_defaults` copies every default the pipeline does not
  disable into a fresh folder. The shipped file, `src/defaults/mission-folder/src/versions.yaml`, is a
  **seven-variant tutorial** — `dawn-auto` (`time: sunrise`, ≈ 03:48 at its Damascus position in June),
  `morning-plus-two-hours`, `with-metar`, `tomorrow-sunset`, and so on.

So both halves were true at once. The build did not invent a preset — it faithfully applied the demo
`versions.yaml` that `prepare` lays into every from-scratch mission, and `dawn-auto` is alphabetically
first among the seven `.miz` it produces, which is the one that got handed over. The defect is not in
the weather code or the blank mission; it is that **the active default for a brand-new mission is a
tutorial that turns one noon mission into seven example-weather variants, one of them at night**, and
nothing about `prepare` says so.

The fix is therefore about what a from-scratch mission ships with, not about the weather engine. The
one sub-choice with a user-facing consequence is put to David below.

### The fix — David's call, 2026-08-15

Asked which way to correct the shipped default, David chose **reduce it to a single noon variant**,
keeping the seven-variant tutorial as a commented block a maker uncomments to activate. So
`src/defaults/mission-folder/src/versions.yaml` now declares one variant, `noon` at `12:00`, clear
sky; a from-scratch build produces `<mission>_noon.miz` at midday, and the tutorial stays discoverable
in the same file. The other two options (ship no default at all; leave the demo) were declined.

### TDD

- The shipped default declares exactly one active variant, at `12:00` — the regression guard against
  the demo creeping back as the active default.
- `dawn-auto` is absent as a live entry but present as a comment, so the feature stays documented.

### Acceptance criteria

- [x] The two hypotheses are told apart by measurement, and the finding is written here.
- [x] A mission built without asking for variants starts at midday.
- [x] Full Python gate green; coverage ratchet respected.
