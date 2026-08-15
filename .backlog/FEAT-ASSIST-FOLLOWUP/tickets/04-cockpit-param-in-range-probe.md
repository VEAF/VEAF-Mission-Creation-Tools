# 04 — Probe `c_cockpit_param_in_range`, then decide whether it is worth using

Status: ⬜ ready
Type: chore

## What this is about

An automatic checklist step validates by reading a value the aircraft publishes. Today
`veafAssist.lua:117` gets that value the only way it knows:

```lua
local dump = veafAssist.inTriggerEnv("return list_cockpit_params()")
```

DCS answers with **one big string** — roughly 19 KB, one `NAME:value` line per parameter. The Lua
splits it line by line, cuts at the **last** colon (a name can contain colons, e.g.
`ExternalFM:HumanInfo:AoA`) and builds a name → number table, then looks up the single parameter the
step cares about.

So the whole catalogue is fetched and parsed to read one value. `veafAssist.paramCache` already
limits that to **one round trip per loop** rather than one per step, which is why this is an
optimisation and not a defect.

`c_cockpit_param_in_range` would let the engine **ask a question** instead of asking for the
catalogue: *is parameter X between A and B?* → yes/no. No 19 KB string, no parsing, no cache to
invalidate.

## What is actually known, and what is not

**Known**: nothing. That is the honest state.

The name comes from a single sentence in `FEAT-ASSIST-CHECKLISTS`'s PRD (now
[archived](../../archive/FEAT-ASSIST-CHECKLISTS.md)), saying it "exists in the mission environment"
and that its signature was never probed because DCS had been closed by then.

**Not known, and to establish in this order:**

1. Does it exist at all in the mission (trigger) environment? Checked the same way ticket 01 of the
   parent lot checked `a_cockpit_highlight`:
   `net.dostring_in("mission", 'return type(c_cockpit_param_in_range)')`.
2. Its signature — how many arguments, in what order. Very likely `(param_name, min, max)`, but that
   is a guess and guessing is what this ticket exists to stop.
3. What it returns for a parameter that does not exist, versus one out of range. Those must be
   distinguishable, or the engine cannot tell "not there" from "not yet".

⚠️ **The name appears nowhere in this repository** — not in `src/`, not in `docs/`, including
`docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md`, which is where every other primitive of this family
was written up after being measured. Treat "it exists" as unverified. It is entirely possible the
answer to step 1 is *no*, and that is a perfectly good outcome for this ticket.

I have also written elsewhere that the `c_` prefix marks *conditions* as opposed to `a_` for
*actions*. That is a plausible ED convention, **not something this repository establishes.** Do not
build on it.

## Do not do this before it is worth doing

The cache means the current cost is one round trip per loop, not per step. So the gain is real but
small, and the risk of the change is not zero — the parsing path is what four F-16C steps and the
whole `param:` mechanism depend on.

Worth revisiting when one of these becomes true:

- a checklist watches many parameters and the per-loop dump starts showing up as a hitch in game;
- the bomb-run checklist (the parent lot's named second client, **fully automatic** on published
  values) lands and multiplies the number of watched parameters;
- someone is in DCS anyway and can answer step 1 in thirty seconds.

That last one is the cheap path: fold the probe into whatever else is being checked in game rather
than opening a session for it.

## Tasks

- [ ] Probe existence and signature, through the smoke harness or by hand, and **report what came
      back** — not that nothing raised. (`FEAT-COMBATZONE-MENU-COALITION` lost time to a check that
      returned a pass whenever `pcall` did not raise.)
- [ ] Write the finding into `docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md`, where the rest of this
      family lives, whichever way it goes.
- [ ] Only then decide whether to use it, and say why in this ticket.

## Acceptance criteria

- [ ] The three unknowns above are answered, or the ticket records that the function does not exist.
- [ ] The exploration document is updated — a probe whose result is not written down will be redone.
- [ ] If adopted: the existing `list_cockpit_params` path stays as a fallback, since a stock install
      may differ, and the `param:` mechanism must not become less reliable than it is today.
