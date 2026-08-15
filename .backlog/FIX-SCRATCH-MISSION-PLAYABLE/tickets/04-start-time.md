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

## The question this ticket answers

A yaml that never mentions weather produced a mission at dawn. Either the build applies a weather
preset when none is asked for — a product defect that will surprise every mission maker who does not
ask for one — or the mission was built through a variant-producing command, in which case the defect
is that **nothing in the output says which moment of day was shipped**.

Do not fix before telling those two apart: build a mission from that exact `mission.yaml` and read
`start_time` out of the result.

- If it comes out at 03:48 → the default is wrong. A mission with no weather section must keep the
  blank mission's midday.
- If it comes out at 12:00 → the build was fine and the variant was handed over blind. Then the fix
  is on the reporting side: a build producing several moments must name the one it wrote.

## TDD

- Building from a `mission.yaml` with no `weather` section leaves `start_time` at `43200`. That test
  is the whole ticket, and it fails today if the first branch is the right one.

## Acceptance criteria

- [ ] The two hypotheses are told apart by measurement, and the finding is written here.
- [ ] A mission built without a weather section starts at midday.
- [ ] Full Python gate green; coverage ratchet respected.
