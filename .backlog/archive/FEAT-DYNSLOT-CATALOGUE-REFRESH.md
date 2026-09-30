# FEAT-DYNSLOT-CATALOGUE-REFRESH — graft Reaper's extract, and fix the two defects it exposed

Status: ✅ done · archived 2026-09-28

Origin: a fresh `dynamic-slot-templates.yaml` handed over by Reaper on 2026-09-21, extracted with our
own `extract-aircraft-groups` from his mission. Shape chosen by David the same day.

## What the extract holds, measured

78 templates, all `dynSpawnTemplate: true`, `skill: Client`, one unit each. Against the shipped
[`src/defaults/mission-folder/src/dynamic-slot-templates.yaml`](../../src/defaults/mission-folder/src/dynamic-slot-templates.yaml)
(104 templates), it is **not a superset**: the shipped catalogue mirrors all 52 blue types in red,
Reaper's has 17 red templates for 16 types. A straight replacement would drop 27 red airplanes, 11
red helicopters, the I-16 and the F4U-1D Mk.IV.

What it does bring, and what this lot takes:

- **14 entries new to their bucket.** 12 are airframes the catalogue does not have at all — blue
  `C-130J-30`, `F-100D`, `F-14BU`, `La-7`, `MB-339APAN`, `MiG-29 Fulcrum`, `P-47D-40`,
  `P-51D-30-NA`, `T-45`; red `J-11A`, `MiG-29S`, `Su-33`. The other 2 (`A-4E-C`, `Bronco-OV-10A`)
  are already shipped, but filed under `helicopters:` — see ticket 03.
- **11 loadouts.** On the 64 shared types, Reaper's template carries strictly more pylons on 11 of
  them, every one of which ships bare today: blue `F-16CM` 0→10, `F/A-18C` 0→9, `Ka-50III` 0→6,
  `M-2000C` 0→5, `Mig-29G` 0→7; red `F-16CM` 0→9, `F-5E-3` 0→3, `F/A-18C` 0→9, `Ka-50` 0→2,
  `M-2000C` 0→5, `Su-27` 0→10. One goes the other way — red `F-14B` 10→0 — and is left alone.

**What this lot does not take, and must never take:** the extract files templates under real
countries (France, Czech Republic, Germany…) instead of `CJTF Blue` / `CJTF Red`. This PRD first
called that "the better model". It is not — the coalition filing is a deliberate design choice, and
David gave the reason on 2026-09-21: a template carrying a real country can demand that country join
a side it is not on.

The mechanics, measured after the fact. `_get_or_create_country` creates a country the target mission
lacks, and since FIX-PREPARE-THEATRE-COALITIONS the injector also calls `assign_country_to_side`, so
the id lands in `coalitions.<side>` and the mission still loads. But that function appends without
checking the **other** side: inject a blue template filed under `France` into a mission where France
is red, and France is listed in `coalitions.blue` *and* `coalitions.red`. `CJTF Blue` (80) and
`CJTF Red` (81) are side-locked by construction and can never collide, which is exactly what a real
country cannot promise. Nothing here is worth "improving".

## The two defects the extract exposed, and they are ours

### The extractor writes a catalogue its own reader cannot read

Reaper's file is **not UTF-8**. It is cp1252, and our loader refuses it:

```
utf-8 read FAILS -> 'utf-8' codec can't decode byte 0xe9 in position 195704
```

The cause is one missing argument. `_write_structure` writes with `open(path, "w")` — no encoding, so
the Windows locale codepage — while `yaml.dump` is called with `allow_unicode=True`, and every reader
in the worker passes `encoding="utf-8"` (lines 162, 554, 1433). Reproduced in three lines:

```
bytes written: b"livery_id: Arm\xe9e de l'air\r\n"
re-read FAILS -> 'utf-8' codec can't decode byte 0xe9 in position 14
```

So as soon as one livery or callsign carries an accent — here `Armée de l'air11` on his AH-64D and
`Déchet11` on his Mi-8MTV2 — the extraction produces a file that `--merge` aborts on and that
injection crashes on. It is silent at write time, and the mission maker's only clue is a
`UnicodeDecodeError` on the next run. `FEAT-EXTRACT-MERGE` worked on that exact line, for the
truncation, and did not see the encoding.

### The templates are hidden by luck, not by the injector

All 104 shipped templates carry `hidden: true` and `lateActivation: true`. All 78 of Reaper's carry
`hidden: false` and no `lateActivation` at all. The injector's `_prepare_injected_group` forces
`hiddenOnPlanner`, `hiddenOnMFD` and the slot password — and **neither `hidden` nor
`lateActivation`**. `FIX-TEMPLATE-SLOTS-VISIBLE` wrote that "the injector already emits `hidden: true`
and `lateActivation: true`": it emitted them because the data happened to carry them. Feed it any
catalogue extracted from a mission where the templates were not hidden by hand, and 78 template
groups land on the F10 map.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [The extractor writes a catalogue it cannot read back](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | fix | ✅ |
| 02 | [The injector hides templates itself, not by luck](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | fix | ✅ |
| 03 | [A mod aircraft is filed by the DCS table, not by its category](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | fix | ✅ |
| 04 | [The shipped catalogue gets an invariants test](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | test | ✅ |
| 05 | [Graft the 12 new airframes, blue and red](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | feat | ✅ |
| 06 | [Graft the 11 loadouts](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | feat | ✅ |
| 07 | [The doc's bare-aircraft example stops being true](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | doc | ✅ |
| 08 | [The validator calls the tool's own output "unusual"](FEAT-DYNSLOT-CATALOGUE-REFRESH.md) | fix | ✅ |

Ticket 08 was **not planned**: the lot's own `pr-code-review` went to check a one-line claim in
ticket 05 — that `DTC` would join the validator's known group keys — measured what the validator
actually reports, and found 262 noise messages on the two shipped catalogues, `dynSpawnTemplate`
among them.

Ordering matters: 04 is written before 05 and 06 so the graft is verified by a test rather than by
reading a 9 500-line YAML, and 01–03 land first because the graft would otherwise re-introduce what
they fix.

### One PR, deliberately over the Sourcery threshold

**Measured: 158 938 diff characters on the catalogue alone**, past the ~150 000 mark where CLAUDE.md
§10 says to split into sequenced PRs. David's call on 2026-09-21, the split having been prepared and
costed: **one PR anyway**, because Sourcery is not reviewing at all at the moment, so splitting buys
nothing it was meant to buy. A full `pr-code-review` takes its place on the open PR.

The size is data, not code: 24 grafted templates and 5 blocks re-serialized where a template moved
bucket or country. What actually changed is verified structurally rather than by reading — see the
Definition of Done below.

## Definition of Done for the lot

- `extract-aircraft-groups` round-trips a catalogue holding an accented livery, proved by a test.
- The injector emits `hidden: true` / `lateActivation: true` whatever the catalogue says, proved by a
  test on the prepared group.
- A mod airframe absent from `dcsUnits.yaml` is filed by its real category, not by the DCS table it
  was found in; `A-4E-C` and `Bronco-OV-10A` sit under `airplanes:` in the shipped catalogue.
- The shipped catalogue holds 128 templates, 64 blue types mirrored by 64 red, every one of them
  `hidden: true` / `lateActivation: true` / at `x: 0, y: 0` / with no `password`, named
  `<X> Template` or `<X> Template Red` — enforced by ticket 04's test, not by inspection.
- 33 templates carry a loadout, up from 18.
- What changed in the catalogue is established **structurally** — the templates loaded before and
  after, compared entry by entry — not by reading the diff, because the diff is 4 000 lines of
  re-serialization and the eye is the tool that misses in it.
- Both shipped catalogues validate with zero messages at any level (ticket 08).
- `poetry run pytest` green, ruff + mypy clean, `poetry run docs-check` green, `CHANGELOG.md`
  updated under `[Unreleased]`.
- The coverage gate is **left at 86.6** rather than raised: measured 86.74 % locally with all
  extras, so the gate already sits 0.14 point below, well inside the ~2-point band CLAUDE.md §3
  requires. Raising it to 86.7 would leave 0.04 of margin against a CI figure that cannot be
  measured here, and this repository has a recorded local-vs-CI gap on exactly this number.

## Deliberately out of scope

- **The three test-mission copies.** `smoke-test-mission`, `verify-mission-a` and `verify-mission-c`
  each carry a byte-identical copy of the shipped catalogue (9 504 lines each). They are scaffolded
  mission folders, not fixtures: nothing reads them as the default and no test enforces that they
  track it. Propagating the graft would add ~195 000 characters of pure duplication to the review for
  no behaviour change, so they stay on the old catalogue. That 28 500 lines of committed duplicate
  is worth a lot of its own; it is not this one.
- **Flyability.** `MiG-29A/S/G`, `Su-33`, `J-11A` and `La-7` look AI-only in stock DCS, and
  `dcsUnits.yaml` carries no flyable flag, so this cannot be settled from the repository. Two things
  weigh the other way: the Mission Editor is what set `skill: Client` on Reaper's templates, and the
  shipped catalogue already carries `Mig-29A` and `Mig-29G`. Grafted as they are; if a type turns out
  not to be selectable in game, the template is inert rather than harmful, and the fix is one deletion.

---

## Tickets, in full

## 01 — The extractor writes a catalogue it cannot read back

Status: ✅ done
Type: fix

### The defect

`AircraftGroupsExtractorWorker._write_structure`
([`aircrafts_injector_worker.py:1531`](../../src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py))
writes the catalogue with `open(path, "w")` — no `encoding`, so the process locale's codepage, which
is `cp1252` on a French Windows. `yaml.dump` is called with `allow_unicode=True`, so any non-ASCII
character in a livery name, a callsign or a group name is written as a cp1252 byte.

Every reader in the same file passes `encoding="utf-8"`:

| line | reader |
|------|--------|
| 162 | `AircraftGroupsValidator.load` |
| 554 | `AircraftGroupsInjectorWorker.load_yaml_data` |
| 1433 | `_merge_into` (the `--merge` path) |

So the extraction produces a file the tool cannot consume. Measured on Reaper's extract of
2026-09-21, which carries `Armée de l'air11` and `Déchet11` as callsigns:

```
utf-8 read FAILS -> 'utf-8' codec can't decode byte 0xe9 in position 195704: invalid continuation byte
```

Reproduced from scratch:

```python
with open(tmp, "w") as f:                      # exactly line 1531
    yaml.dump({"livery_id": "Armée de l'air"}, f, allow_unicode=True, ...)
# bytes written: b"livery_id: Arm\xe9e de l'air\r\n"
# yaml.safe_load(open(tmp, encoding="utf-8").read()) -> UnicodeDecodeError
```

What the mission maker sees: the extraction reports success, and the next command — a build, an
injection, or a second `--merge` extraction — dies on a `UnicodeDecodeError` naming a byte offset.
`_merge_into` catches it and calls `logger.error`, which aborts (see the `logger-error-aborts`
measurement), so a `--merge` run refuses to do anything at all.

### What to do

Pass `encoding="utf-8"` at line 1531. Check the rest of the worker for the same asymmetry — any
`open(..., "w")` or `write_text` without an explicit encoding — and fix those too.

Do **not** drop `allow_unicode=True`: escaping the accents would keep the file readable but make the
liveries unreadable to a human editing the catalogue by hand, which is the documented workflow.

### Definition of Done

- A test writes a structure holding an accented livery through `_write_structure` and reads it back
  through `AircraftGroupsValidator.load` (or `load_yaml_data`) — it must fail on the current code.
- A test asserts the bytes on disk are UTF-8, so the fix cannot regress to the locale default by
  someone dropping the argument.
- No other unencoded write remains in `aircrafts_injector_worker.py`.

---

## 02 — The injector hides templates itself, not by luck

Status: ✅ done
Type: fix

### The defect

`FIX-TEMPLATE-SLOTS-VISIBLE` made injected templates invisible as pickable slots, and its PRD states
that "the injector already emits `hidden: true` (map only) and `lateActivation: true`". It does not.
`_prepare_injected_group`
([`aircrafts_injector_worker.py:714`](../../src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py))
sets three fields and only three:

```python
prepared["hiddenOnPlanner"] = True
prepared["hiddenOnMFD"] = True
prepared["password"] = _TEMPLATE_SLOT_PASSWORD
```

`hidden` and `lateActivation` appear in the worker exactly once each, in the validator's list of
known group keys (lines 389 and 395). No code ever writes them. The shipped catalogue carries
`hidden: true` / `lateActivation: true` on all 104 templates, so the output looked right — the data
was doing the work.

Measured on Reaper's extract: **`hidden: false` on all 78 templates, `lateActivation` absent from 77
and `false` on the last one.** Injected as-is, that is 78 template groups drawn on the F10 map of
every mission built from that catalogue. The extraction cannot fix this either: it reports what the
mission holds, and a mission maker configuring templates in the Mission Editor has no reason to tick
"hidden" on each one.

### What to do

Force both in `_prepare_injected_group`, alongside the three existing fields, with a comment saying
why the catalogue is not trusted for them. A template group is never meant to be visible or active:
it exists to be referenced by name by the dynamic-spawn machinery.

### Definition of Done

- `_prepare_injected_group` returns `hidden: True` and `lateActivation: True` whatever the source
  group carried.
- A test feeds it a group with `hidden: false` and no `lateActivation` — Reaper's exact shape — and
  asserts both come out true. It must fail on the current code.
- The source dict is still not mutated (the existing deep-copy contract).

---

## 03 — A mod aircraft is filed by the DCS table, not by its category

Status: ✅ done
Type: fix

### The defect

`FIX-DYNSLOT-TEMPLATE-CATEGORY` fixed the general case: DCS files a dynamic-slot template under the
`helicopter` table whatever the aircraft is, so `aircraft_category_for_group` now routes by the
unit's **real** category, read from `dcsUnits.yaml`. When the type is not in `dcsUnits.yaml` it falls
back to the DCS table it was found in — and that fallback is where mod aircraft land.

`dcsUnits.yaml` is generated from the `dcs-lua-datamine` pin and carries stock content only. Measured:

| type | in `dcsUnits.yaml` | shipped bucket |
|------|--------------------|----------------|
| `A-4E-C` | absent | `helicopters:` ❌ |
| `Bronco-OV-10A` | absent | `helicopters:` ❌ |
| `T-45` | absent | — (arrives with ticket 05) |

So the shipped catalogue files a Skyhawk and a Bronco as helicopters, in both coalitions, and
`test_dynslot_defaults_category.py` cannot catch it — its check `continue`s on a type
`dcsUnits.yaml` does not know. Reaper's extract has all three under `airplanes:`, because his mission
happens to hold them in the `plane` table, which is luck rather than a fix.

Consequences beyond tidiness: the injector puts an `airplanes:` template into `country["plane"]` and a
`helicopters:` one into `country["helicopter"]`, and the warehouses step stocks airfields from the
template's bucket. A Skyhawk filed as a helicopter is offered on helicopter pads.

The file says `DO NOT EDIT BY HAND — CI fails if this file drifts from the generator output`, so the
three types cannot simply be added to it.

### What to do

A small curated override, consulted by `aircraft_category_for_group` **before** the fallback: a
mapping of mod type ids to their real category, seeded with `A-4E-C`, `Bronco-OV-10A` and `T-45`.
Keep it next to the categorizer with a comment saying it exists because `dcsUnits.yaml` is stock-only
and must not be hand-edited, and that an entry becomes dead the day a type enters the datamine —
harmless, since the override and the datamine would then agree.

Then move the four misfiled templates in the shipped catalogue: `A-4E-C Template`,
`A-4E-C Template Red`, `OV-10A Template`, `OV-10A Template Red`, from `helicopters:` to `airplanes:`,
content unchanged.

### Definition of Done

- `aircraft_category_for_group({"units": [{"type": "A-4E-C"}]}, fallback="helicopters")` returns
  `"airplanes"`.
- The override is consulted after `dcsUnits.yaml`, not before it: a type present in the datamine wins,
  so the override can never contradict the generated truth.
- `test_dynslot_defaults_category.py` builds its expected bucket through the same path as the code
  (datamine **then** override), so the shipped catalogue is now enforced for these types instead of
  skipped — it must fail before the four templates are moved.
- The four templates sit under `airplanes:` in the shipped catalogue.

---

## 04 — The shipped catalogue gets an invariants test

Status: ✅ done
Type: test

### Why, before the graft rather than after

Tickets 05 and 06 add 24 templates and rewrite 11 loadouts inside a 9 504-line YAML, by script. A
scripted edit that finds nothing reports nothing — this repository has already shipped four commits
that each claimed to bump a version and left it untouched. Reading the result back by eye is not a
check, so the invariants the graft must preserve are written down first, as assertions.

Measured on the catalogue as it stands, so the test very nearly passes today:

- 104 templates, `hidden: true` and `lateActivation: true` on all 104, `x: 0` / `y: 0` at group
  **and** unit level on all 104, no `password` on any, one unit each, `skill: Client` and
  `dynSpawnTemplate: true` throughout.
- The group's `name:` equals its YAML key on all 104; the unit is named `<group name> #01` on all
  104; the single route point is named after the group on 103.
- 52 blue types **exactly** mirrored by 52 red types — no blue-only, no red-only.
- Two blemishes, both fixed by this ticket:
  - `CH-47F Template-1` is the only name off the `<X> Template` / `<X> Template Red` convention (its
    red counterpart is correctly `CH-47F Template Red`, and its own route point is already named
    `CH-47F Template` — it is the 103/104 above). Nothing outside the catalogue copies references the
    name, so renaming it to `CH-47F Template` breaks nothing and makes it self-consistent.
  - `F-15E S4+ Template Red` is filed under country `Russia` while the other 51 red templates are
    under `CJTF Red`. The warehouses step matches templates by name, not country, so moving it is
    safe.

### What to do

One test module asserting, on the shipped catalogue:

| invariant | why it matters |
|-----------|----------------|
| `hidden: true` and `lateActivation: true` on every template | a visible template is drawn on the F10 map (ticket 02) |
| `x == 0` and `y == 0`, group and unit | a template carries no position; Reaper's extract has real coordinates from two different areas |
| no `password` key | the injector sets its own; a foreign hash in the catalogue is noise |
| `dynSpawnTemplate: true`, exactly one unit, `skill: Client` | what makes it a dynamic-slot template at all |
| name is `<X> Template` or `<X> Template Red`, equals the group's own `name:` field and its route point's, and the unit is `<name> #01` | the warehouses step references templates **by name** |
| blue country is `CJTF Blue`, red country is `CJTF Red` | the catalogue's own convention, not enforced anywhere today |
| the set of blue types equals the set of red types | the mirror is the catalogue's promise; ticket 05 has to hold it |
| `groupId` and `unitId` unique across the file | duplicates are a DCS load failure, and the injector does not renumber |

Then fix the two blemishes so it passes.

### Definition of Done

- The test fails on the catalogue before the two blemishes are fixed, naming them.
- It passes after, and is the thing that verifies tickets 05 and 06 rather than a read-through.
- It states the expected template count as a **floor**, not an equality, so adding a template later is
  not a test edit.

### Note, not in scope

The injector does not renumber `groupId` / `unitId` on injection — `mission_tools.group_insertion`
does it for the MCP path, `aircrafts_injector` does not. The catalogue's ids (145–520 / 18–605) can
therefore collide with the target mission's. That is pre-existing, it is not what this lot is about,
and the uniqueness assertion above only covers collisions **inside** the catalogue.

---

## 05 — Graft the 12 new airframes, blue and red

Status: ✅ done
Type: feat

### What arrives

Twelve airframes the shipped catalogue does not have, taken from Reaper's extract of 2026-09-21:

| coalition in the extract | type | his template | DCS name |
|---|---|---|---|
| blue | `C-130J-30` | `Template C130J-30` | C-130J-30 |
| blue | `F-100D` | `Template F-100D` | F-100D |
| blue | `F-14BU` | `Template F-14BU` | F-14B(U) |
| blue | `La-7` | `Template La-7` | La-7 |
| blue | `MB-339APAN` | `Template MB-339` | MB-339A/PAN |
| blue | `MiG-29 Fulcrum` | `Template Mig-29A Fulcrum` | MiG-29A Fulcrum |
| blue | `P-47D-40` | `Template P-47D-40` | P-47D-40 |
| blue | `P-51D-30-NA` | `Template P-51D-30` | P-51D-30-NA |
| blue | `T-45` | `Template T-45` | T-45 |
| red | `J-11A` | `Template J-11A Red` | J-11A |
| red | `MiG-29S` | `Template MiG-29S Red` | MiG-29S |
| red | `Su-33` | `Template Su-33 Red` | Su-33 |

Each one gets its mirror in the other coalition, so **24 templates** are added and the catalogue goes
from 104 to 128, 64 blue types against 64 red.

Only two carry a loadout in the extract: `MiG-29S` (7 pylons) and `Su-33` (12). The other ten are
bare, like most of the catalogue.

### Normalizing on the way in

Reaper's file follows his mission's conventions, not the catalogue's. Each grafted template is
rewritten to the shipped shape — ticket 04's test is what proves it, so nothing here needs to be
checked by reading the YAML:

| his | ours |
|-----|------|
| `Template M-2000C` | `M-2000C Template` / `… Template Red` |
| country `France`, `USA`, `Russia`, … | `CJTF Blue` / `CJTF Red` |
| `hidden: false`, no `lateActivation` | `hidden: true`, `lateActivation: true` |
| real `x` / `y` (two distinct areas, so two maps) | `0` / `0`, group and unit |
| `password: lG3jX1_GswM:…` | dropped — the injector sets its own |
| unit named like the group | `<group name> #01` |
| route point named like his group | named after ours |
| `groupId` 60–3899, `unitId` 223–7374 | allocated above the catalogue's current maxima (520 / 605) |

Kept as they are: `livery_id`, `callsign`, `payload`, `AddPropAircraft`, `task`, `frequency`,
`alt`. A red mirror keeps the blue template's livery — the catalogue already does that in places
(`Ka-50 Template Red` wears an Italian livery), and inventing liveries is not this lot's job.

`F-14BU` and `MiG-29 Fulcrum` carry a group-level `DTC` block (the module's data cartridge). It is
real configuration, so it is kept. Silencing the *unusual field* message it raises turned out to be
the smaller half of a larger defect — the validator did not know four other fields the tool itself
produces — and moved to [ticket 08](FEAT-DYNSLOT-CATALOGUE-REFRESH.md).

### Definition of Done

- 24 templates added; ticket 04's test passes, including the blue/red mirror equality and the id
  uniqueness.
- The mission maker's names are the DCS names, so a template is recognizable in the Mission Editor's
  warehouse dialog: `C-130J-30 Template`, `F-100D Template`, `F-14BU Template`, `La-7 Template`,
  `MB-339 Template`, `MiG-29 Fulcrum Template`, `P-47D-40 Template`, `P-51D-30 Template`,
  `T-45 Template`, `J-11A Template`, `Mig-29S Template`, `Su-33 Template`, each with its `… Red`.
  (`Mig-29S` keeps the lower-case spelling of its siblings `Mig-29A` / `Mig-29G` rather than
  introducing a second convention in the same family.)
- The defaults lockstep (CLAUDE.md §9.7) does not apply: this changes no generated output, only the
  shipped catalogue, which **is** the default.

---

## 06 — Graft the 11 loadouts

Status: ✅ done
Type: feat

### What changes

The shipped catalogue ships **18 of its 104 templates with a loadout** — 17 %. DCS serves the pilot
the aircraft *as the template describes it*, so the other 86 come out bare. Reaper's extract carries a
loadout on 11 types that ship empty:

| coalition | type | template | pylons |
|---|---|---|---|
| blue | `F-16C_50` | `F-16CM Template` | 0 → 10 |
| blue | `FA-18C_hornet` | `F/A-18C Template` | 0 → 9 |
| blue | `Ka-50_3` | `Ka-50III Template` | 0 → 6 |
| blue | `M-2000C` | `M-2000C Template` | 0 → 5 |
| blue | `MiG-29G` | `Mig-29G Template` | 0 → 7 |
| red | `F-16C_50` | `F-16CM Template Red` | 0 → 9 |
| red | `F-5E-3` | `F-5E-3 Template Red` | 0 → 3 |
| red | `FA-18C_hornet` | `F/A-18C Template Red` | 0 → 9 |
| red | `Ka-50` | `Ka-50 Template Red` | 0 → 2 |
| red | `M-2000C` | `M-2000C Template Red` | 0 → 5 |
| red | `Su-27` | `Su-27 Template Red` | 0 → 10 |

With ticket 05's `MiG-29S` and `Su-33` and their mirrors, the catalogue goes from 18 armed templates
to 33 out of 128 — 26 %.

### What is taken, and what is not

**The `payload` block only**, whole: `pylons`, `fuel`, `chaff`, `flare`, `gun`, `ammo_type`. Keeping
the graft to one key per template keeps the diff auditable, which matters on a 9 500-line YAML.

Explicitly not taken:

- **`livery_id`.** Reaper's liveries follow his real-country filing (a Czech L-39, a Luftwaffe
  MiG-29G); this lot keeps `CJTF Blue` / `CJTF Red`, so his liveries would be arbitrary here — and
  two of them are plainly wrong for their side anyway (his red JF-17 and red Mirage F1EE both wear
  blue camouflage).
- **`AddPropAircraft`.** His differ from ours on several types, in both directions, and the
  differences are module option drift rather than an improvement. Left alone.
- **Red `F-14B`.** The one type where the extract is poorer: `F-14B Template Red` carries 10 pylons
  today and 0 in his file. Not touched.

### Definition of Done

- The 11 templates carry their new `payload`, and nothing else about them changed — verifiable by
  the diff being one block per template.
- 33 templates in the catalogue carry a non-empty `payload.pylons`, asserted as a floor by ticket
  04's test so the count cannot silently fall back.
- Every `CLSID` in the grafted pylons is a string, non-empty, and the pylon keys are integers — a
  malformed pylon table is a DCS load failure and this is data copied from a foreign file.

---

## 07 — The doc's bare-aircraft example stops being true

Status: ✅ done
Type: doc

### What breaks

[`doc/mission-maker/concepts/dynamic-slots.md`](../../doc/mission-maker/concepts/dynamic-slots.md),
section *Le piège*:

> Sur les modèles fournis par défaut, une petite minorité seulement porte un emport : un A-10C II
> sort armé et peint, un **UH-1H ou un F/A-18C sortent nus**.

Ticket 06 arms the F/A-18C. The claim becomes false the moment the graft lands, in the one page a
mission maker reads to understand why their pilots spawn with empty pylons.

The headline — *a small minority* — stays true: 33 of 128 after the graft, against 18 of 104 before.
26 % is still a minority, so the advice does not change; the example does.

### What to do

- Swap the F/A-18C for an airframe that is still bare after tickets 05 and 06 — the UH-1H stays bare,
  and there are 95 others to choose from. Pick one the reader will recognize.
- Same edit in [`dynamic-slots.en.md`](../../doc/mission-maker/concepts/dynamic-slots.en.md).
- While in the page: it is the page that tells the mission maker to re-extract from their own mission
  (`extract-aircraft-groups --kind dynamic-template`), which is exactly the path that hit ticket 01's
  encoding defect. Nothing to add once the defect is fixed, but check the surrounding wording still
  reads true.

### Definition of Done

- Both language versions name a template that is genuinely bare in the shipped catalogue, verified
  against the file rather than assumed.
- `poetry run docs-check` green.
- No version string written into the page header (CLAUDE.md §7).

---

## 08 — The validator calls the tool's own output "unusual"

Status: ✅ done
Type: fix

Found by the `pr-code-review` of this lot's own PR, chasing a smaller claim: ticket 05 said `DTC`
would be added to the validator's known group keys. It measured what the validator actually says,
and the answer was much larger than `DTC`.

### The measurement

`AircraftGroupsYAMLValidator.validate()` run on the two **shipped** catalogues, before the fix:

| catalogue | field reported *unusual* | occurrences |
|-----------|--------------------------|-------------|
| `dynamic-slot-templates.yaml` | `dynSpawnTemplate` | 128 |
| `dynamic-slot-templates.yaml` | `uncontrollable` | 128 |
| `dynamic-slot-templates.yaml` | `DTC` | 4 |
| `spawnables.yaml` | `hiddenOnPlanner` | 1 |
| `spawnables.yaml` | `hiddenOnMFD` | 1 |

**262 messages, and every one of them is noise.** `dynSpawnTemplate` is the flag that *defines* a
dynamic-slot template — `classify_aircraft_group` sorts the family on it. `hiddenOnPlanner` and
`hiddenOnMFD` are written by `_prepare_injected_group`, so the tool flags what it wrote itself one
step earlier. `uncontrollable` and `DTC` are ordinary DCS group fields the Mission Editor emits.

`_check_group_structure` lists the keys it knows and reports the rest at `info`, whose stated purpose
is *"this might be a typo or extracted metadata that should be removed"*. With 262 false ones, a
genuine typo arriving in that stream is invisible. This repository has the measurement for that
already, on a log written 124 lines a minute where its own comment claimed a few hundred per sortie.

### Why it belongs to this lot rather than a later one

The lot grafts 24 templates, each adding two more of those messages, and ticket 05 committed to the
`DTC` half of the fix. Doing only that half — silencing 4 while leaving 256 — would be cosmetic, and
it would leave the list still missing the field the family is defined by.

### What was done

The five measured fields are added to `common_group_keys`, with a comment recording the count and
why the tool's own output was missing from its own whitelist. No speculative entries: only what the
shipped catalogues actually carry.

### Definition of Done

- Both shipped catalogues validate with **zero** messages at any level, asserted by
  `ShippedCataloguesValidateSilentlyTest` — a ratchet, so the next field the extractor starts
  emitting has to be classified rather than added to the noise.
- The test fails without the fix, on both catalogues (verified by reverting).
- Nothing else in the validator changes: a field that really is unknown is still reported.

---
