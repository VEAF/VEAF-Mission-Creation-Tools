# 04 — A mission nobody asked to fly at night starts at 03:48

Status: ⬜ ready
Type: fix
Files: the build chain between `blank_mission` and the produced `.miz` — `weather_injector` is the
prime suspect; tests

## The complaint

David, 2026-08-15, listing what was wrong with the mission handed to him for the DCS session: *"en
plus tu me la fais démarrer de nuit"*. Third defect of the same mission as tickets 01 and 03, and the
only one that was **not** written down anywhere until now.

## What is measured

- `blank_mission.py:82` ships `"start_time": 43200` — **12:00, midday**. The blank mission is innocent.
- Both `TestMenuFR.miz` and David's `TestMenuFR-david.miz` carry `start_time = 13695` — **03:48**.
- **`13695` appears nowhere in the repository.** It is a *computed* value.
- `weather_injector_worker.py:274` is the one place that writes `mission_content["start_time"]`, and
  its `dawn` preset is `sunrise+30*60` — a computed dawn, consistent with 03:48 on the Caucasus in June.
- The session's `mission.yaml` (kept as `mission.yaml-source` next to the mission) declares **no**
  weather section at all. The `WEATHER` module it lists is the runtime Lua module, not the injector.

## Told apart by measurement — 2026-08-15

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

## The fix — David's call, 2026-08-15

Asked which way to correct the shipped default, David chose **reduce it to a single noon variant**,
keeping the seven-variant tutorial as a commented block a maker uncomments to activate. So
`src/defaults/mission-folder/src/versions.yaml` now declares one variant, `noon` at `12:00`, clear
sky; a from-scratch build produces `<mission>_noon.miz` at midday, and the tutorial stays discoverable
in the same file. The other two options (ship no default at all; leave the demo) were declined.

## TDD

- The shipped default declares exactly one active variant, at `12:00` — the regression guard against
  the demo creeping back as the active default.
- `dawn-auto` is absent as a live entry but present as a comment, so the feature stays documented.

## Acceptance criteria

- [x] The two hypotheses are told apart by measurement, and the finding is written here.
- [x] A mission built without asking for variants starts at midday.
- [x] Full Python gate green; coverage ratchet respected.
