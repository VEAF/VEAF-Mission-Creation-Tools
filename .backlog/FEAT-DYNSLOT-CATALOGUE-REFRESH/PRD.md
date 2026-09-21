# FEAT-DYNSLOT-CATALOGUE-REFRESH — graft Reaper's extract, and fix the two defects it exposed

Status: ✅ done

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
| 01 | [The extractor writes a catalogue it cannot read back](tickets/01-extraction-writes-unreadable-yaml.md) | fix | ✅ |
| 02 | [The injector hides templates itself, not by luck](tickets/02-injector-forces-hidden-and-late-activation.md) | fix | ✅ |
| 03 | [A mod aircraft is filed by the DCS table, not by its category](tickets/03-mod-aircraft-category-override.md) | fix | ✅ |
| 04 | [The shipped catalogue gets an invariants test](tickets/04-catalogue-invariants.md) | test | ✅ |
| 05 | [Graft the 12 new airframes, blue and red](tickets/05-graft-new-airframes.md) | feat | ✅ |
| 06 | [Graft the 11 loadouts](tickets/06-graft-loadouts.md) | feat | ✅ |
| 07 | [The doc's bare-aircraft example stops being true](tickets/07-doc-loadout-example.md) | doc | ✅ |
| 08 | [The validator calls the tool's own output "unusual"](tickets/08-the-validator-calls-its-own-output-unusual.md) | fix | ✅ |

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
