# 01 — Reproduce, then fix the blank mission's coalitions

Status: ⬜ ready

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

## Definition of done

- [ ] Reproduced (or closed as not reproducible, with the evidence)
- [ ] A mission from `prepare --theatre` + `build` loads in DCS — or at minimum passes `validate`,
      and say plainly which of the two you were able to check
- [ ] A test over the **whole path**: prepare → build → validate. The defect lives in the seam
      between commands, so a test of either alone would miss it, and did
- [ ] The tutorial's corresponding step still holds
