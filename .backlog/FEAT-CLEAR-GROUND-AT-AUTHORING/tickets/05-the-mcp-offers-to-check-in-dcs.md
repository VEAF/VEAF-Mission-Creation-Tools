# 05 — the MCP offers to check its own work in DCS

Status: ⬜ ready — depends on ticket 04, and it is the gate rather than the fix
Type: feat

## What this builds

The other half of David's original idea, and deliberately last: the server produces a `.miz`, offers
to launch DCS, loads it, reads back which ground units stand in scenery, and reports.

It is the **only** way to validate the end result for real. Everything upstream — the catalogue, the
query, the placement — is a model of the terrain, and a model gets checked against the thing itself.

## What it must measure, and where

**Probe before the units exist, or the numbers are worthless.** This is the mistake that cost two
days: measured after a spawn, a tight SAM battery fails its own test wherever it stands, because the
probe counts vehicles as obstacles. Three published figures were wrong that way — 81, 76 and 69.

So this check must either probe the intended positions **before** spawning, or account for the
group's own vehicles — and it must state which of the two it did, in the report it produces. A
report that does not say how it counted is how this went wrong the first time.

## Definition of done

- [ ] The MCP can launch DCS on a generated mission and read ground unit positions back
- [ ] The report counts vehicles in scenery with a criterion that does not count their own
      neighbours, and names the criterion it used
- [ ] The offer is an offer: nothing launches DCS without being asked
- [ ] A mission built through ticket 04 is verified this way, and the result is compared with what
      the catalogue predicted. A disagreement is a finding about the catalogue, not noise to smooth
      over
- [ ] Python tests green
