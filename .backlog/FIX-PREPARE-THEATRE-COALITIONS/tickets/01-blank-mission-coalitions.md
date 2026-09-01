# 01 — Reproduce, then fix the blank mission's coalitions

Status: ✅ done

Type: fix · Files: wherever `--theatre` generates the blank mission, plus the build's group injection

## Step one is reproduction, and it may fail

Run, in a **real Windows console** (`prepare` drives an interactive prompt and refuses a captured
or Git Bash session — "No Windows console found"):

```
veaf-tools prepare --template minimal --theatre Caucasus <folder>
veaf-tools build
veaf-tools extract
veaf-tools validate
```

Expected per the report: `validate` complains that side `blue` holds units while no country is
assigned to it, and says DCS will refuse to load the mission.

If it does not reproduce, **stop and close the lot with that finding**. The report comes from a
single run by another agent and has not been confirmed since; an invented fix would be worse than
no lot.

## If it reproduces

The offered explanation: the build injects aircraft groups under `coalition.<side>.country`, while
the blank mission `--theatre` generates leaves `coalitions = { blue = {}, red = {} }` empty. Verify
that before acting on it — read what `--theatre` actually writes, and what the build actually adds.

Then decide where the fix belongs. Both are defensible and they are not equivalent:

- **In the generator**: a blank mission declares a country per side from the start. Simple, but it
  bakes a choice of country into every generated mission.
- **In the injector**: whatever adds a group to a side ensures that side has a country. Narrower in
  intent and fixes the same failure whatever produced the mission — including missions from other
  sources.

Say which you chose and why.

## What was done

Reproduced with, from the repo, into an **empty** target folder (no console needed — the
"No Windows console found" comes from the overwrite prompt, which an empty folder never triggers):

```
poetry run veaf-tools mission prepare --template minimal --theatre Caucasus <folder>
poetry run veaf-tools mission build mission.miz <folder> --scripts-path <scripts-root>
poetry run veaf-tools mission extract <folder>/My-Mission_<date>.miz <folder>
poetry run veaf-tools mission validate <folder>
```

`validate` reported the error for **both** blue and red. The extracted table showed
`coalitions = { blue = {}, neutrals = {}, red = {} }` against six unit-owning countries: USA (2),
France (5), CJTF Blue (80) / Russia (0), USSR (68), CJTF Red (81).

**Chosen: the injector.** Two places create countries and neither assigned them —
`aircrafts_injector._get_or_create_country` (the shipped `spawnables.yaml` and
`dynamic-slot-templates.yaml`) and `mission_builder.coalition_placeholder` (the per-side
placeholder). Both now call `mission_tools.group_insertion.assign_country_to_side`, which
`group_insertion.add_group` — the MCP path — has always called; `blank_mission.py`'s docstring
already claimed every group-adding path did.

The generator option was rejected as *wrong*, not merely broader: `coalitions.<side>` must list
**every** country that owns units on that side. Declaring one country in the blank mission would
satisfy `validate` — which only reports a side with no country at all — while five of the six stayed
unassigned and DCS still refused the mission. It would have hidden the defect.

## Definition of done

- [x] Reproduced (or closed as not reproducible, with the evidence)
- [x] A mission from `prepare --theatre` + `build` loads in DCS — or at minimum passes `validate`,
      and say plainly which of the two you were able to check → **`validate` only**; no DCS on this
      machine. Beyond `validate` (which is satisfied by one assigned country), the test asserts the
      real invariant: every unit-owning country id appears in `coalitions.<side>`
- [x] A test over the **whole path**: prepare → build → validate. The defect lives in the seam
      between commands, so a test of either alone would miss it, and did →
      `test/python/test_prepare_theatre_build_validate.py`, driving the real CLI commands. Verified
      to fail without the fix (`countries [2, 5, 80] own units but are not listed in coalitions.blue`)
- [x] The tutorial's corresponding step still holds — `doc/mission-maker/TUTORIAL.md` line 44 is the
      command that was re-run; no doc change needed
