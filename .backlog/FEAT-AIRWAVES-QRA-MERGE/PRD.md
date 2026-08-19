# FEAT-AIRWAVES-QRA-MERGE — rebuild QRA on AirWaves instead of beside it

Status: ⬜ ready

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

- [ ] The comparison exists and carries an explicit go/no-go
- [ ] An existing mission's `modules.QRA` block still works, unchanged, with a test proving it
- [ ] The six issues each either delivered or closed against the recorded decision
- [ ] No pilot-facing label changed without its catalogue entry following
