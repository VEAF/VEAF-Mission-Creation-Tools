# 03 — aspect and a priority cut-off in the target ranking

Status: ⬜ ready
Type: feature
Issue: [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187)

## Need

The ranking in `veafSpawn.startCapWatchdog` uses type and distance only. #187 asks for:

- the target's **aspect** relative to the CAP (hot, cold, flanking) to weigh in the priority;
- a **cut-off** beyond which a target is not engaged at all, depending on the group's mission
  (escort vs CAP).

## Acceptance

- The aspect computation is a pure function with its own tests (hot, cold, flanking, at the
  boundaries).
- A target past the cut-off is not tasked; the cut-off differs between the roles that use the
  watchdog.
- The ladder is documented next to the existing one in the code.
