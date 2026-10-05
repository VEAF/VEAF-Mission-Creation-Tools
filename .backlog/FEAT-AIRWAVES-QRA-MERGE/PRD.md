# FEAT-AIRWAVES-QRA-MERGE — rebuild QRA on AirWaves instead of beside it

Status: 🧑 waiting-human — code done; waits on its in-game check, R43 in `DCS-SESSION-TODO.md`

Origin: David, 2026-08-17, closing the six open AirWaves issues into one design:
[#185](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/185) (replace the QRA module),
[#186](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/186) (mobile zone, e.g. a carrier),
[#183](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/183) (link a zone to airbases or
other entities), [#182](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/182) (friendly
waves), [#179](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/179) (no coming back once
dead), [#176](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/176) (unimportant groups).

## The idea, in David's words

Redo QRA **on top of AirWaves** — a code optimisation, not a new feature. The six issues above are
not six tickets; they are the shape AirWaves needs in order to be the thing QRA is built on.

## What the numbers say

Two modules do neighbouring work: `veafAirWaves.lua` is **59 KB**, and the QRA trio
(`veafQraCore` + `veafQraLogistics` + `veafQraManager`) is **61 KB**. Roughly 120 KB to watch a zone,
decide that something should scramble, spawn it, and track whether it died.

And #185 never started: **`veafAirWaves.lua` mentions QRA not once** — grepped. So "replace the QRA
module" has been an intention for three years with no line of code behind it.

## Why it is a design lot before it is a refactor

A merge is only an optimisation if the two behaviours really are one behaviour with different
settings. That has to be established, not assumed. The questions to answer **first**, in writing:

- **What does QRA do that AirWaves cannot?** Its logistics half (`veafQraLogistics`) has no AirWaves
  equivalent, and the recent `active_at_start` and dynamic-slot work
  (`FIX-QRA-DYNSLOT-CATEGORY`, `FEAT-ACTIVATION-CONTROLS`) landed on QRA, not on waves.
- **What does AirWaves do that QRA cannot?** Waves, and the notion of a zone being *won* or *lost* —
  which is what #182 and #179 extend.
- **Are they one model?** A QRA is arguably a single-wave AirWave with a re-arm rule. If that holds,
  the merge is real. If it does not, this becomes "AirWaves gains five features" and QRA stays, and
  that is an acceptable outcome to reach explicitly rather than by drift.

## Decision (2026-10-05)

**Option b, one PR**: no merge of the behaviours, one shared base under both modules.
The written comparison is [comparison.md](comparison.md): a QRA and an air-wave zone look at the scene from opposite sides and their life cycles differ in shape, while the zone, drawing, altitude, group-choice and spawn code is duplicated.
The shared base carries #183 (entity link, generalising `airport_link`) and #186 (mobile zone); #182, #179 and #176 land in AirWaves alone; QRA and AirWaves keep their state machines, public API and labels.
Added on the way, at David's request: the QRA logistics declared in `mission.yaml` (ticket 08). And #1078 — QRA and waves reading a command's groups before a deferred spawn — is fixed in the shared spawn, now its only site.

## Migration is the hard half

Every VEAF mission declares QRAs in `mission.yaml`, and `FEAT-ACTIVATION-CONTROLS` added keys to that
schema this month. So:

- existing `modules.QRA` declarations must keep working, whatever happens underneath — a mission maker
  does not rewrite their mission because we merged two modules
- `convert-v5` extracts QRA chains (`_extract_qra_chains`), and that extraction has to keep landing
  somewhere valid
- the pilot-facing surface (F10 menu labels, messages) is localised since `FIX-RADIO-MENU-I18N`;
  a merge that changes label text changes 48 catalogue entries

## Scope

1. **The comparison**, written down: behaviour by behaviour, which module has it, what the merged
   model would look like. Ends with a go/no-go on the merge itself.
2. If go: the five AirWaves capabilities the issues ask for (#186 mobile zone, #183 entity link, #182
   friendly waves, #179 no return once dead, #176 unimportant groups), since they are what QRA needs
   from the host.
3. QRA rebuilt on that engine, with its YAML schema unchanged from the outside.
4. If no-go: say so, ship whichever of the five capabilities stand on their own, and close the rest.

## Definition of done

- [x] The comparison exists and carries an explicit go/no-go
- [x] An existing mission's `modules.QRA` block still works, unchanged, with a test proving it — the QRA Lua suite passes with no assertion changed (one test double now goes through `veaf.collectSpawnedGroup`, the real insertion point), and so does the generator sweep (`test_qra_keys_reach_the_lua.py`); the in-game check is R43 of `DCS-SESSION-TODO.md`
- [x] The six issues each either delivered or closed against the recorded decision — #185 answered by the comparison, the five others delivered
- [x] No pilot-facing label changed without its catalogue entry following — no label changed; three new messages added to the catalogue (`airwaves.msg_paused`, `msg_closed`, `msg_lost_friendlies`)

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**rebuild QRA on AirWaves instead of beside it.** David's idea, 2026-08-17, and it closes the six open AirWaves issues (#185, #186, #183, #182, #179, #176) into one design rather than six tickets. The numbers that make it worth doing: two modules do neighbouring work — `veafAirWaves.lua` is **59 KB** and the QRA trio **61 KB** — roughly 120 KB to watch a zone, scramble something, and track whether it died. And #185 never started: `veafAirWaves.lua` mentions QRA **not once**, so "replace the QRA module" has been an intention for three years with no code behind it. **A design lot before a refactor**, deliberately: a merge is only an optimisation if the two behaviours are one behaviour with different settings, and that must be established — a QRA is arguably a single-wave AirWave with a re-arm rule, but `veafQraLogistics` has no AirWaves equivalent and this month's `active_at_start` work landed on QRA. **No-go is an acceptable outcome**, reached explicitly rather than by drift. The hard half is migration: every VEAF mission declares QRAs in `mission.yaml`, so the schema must keep working from the outside, `convert-v5`'s extraction must still land somewhere valid, and a merge that reworded a pilot-facing label would move 48 catalogue entries
