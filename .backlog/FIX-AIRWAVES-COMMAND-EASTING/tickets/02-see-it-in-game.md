# 02 — See a command-driven wave arrive where it should

Status: 🧑 waiting-human
Type: chore

Needs DCS started, so it is David's to run. Listed in
[`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md).

## Why it is worth looking at rather than assuming

The unit tests prove the vec3 leaves `deployWaves` and `deploy` correctly shaped. They cannot say
what DCS *did* with the broken one, and the PRD flagged that as unmeasured: a nil easting reads as
the theatre's central meridian, so the expected before/after is a group appearing hundreds of
kilometres west of its zone versus inside it. Worth confirming once, because it also tells us whether
this failed loudly (a group visibly nowhere) or quietly (a group that never engaged and was written
off as an AI quirk) — which is the difference between a fixed annoyance and a fixed mystery.

## What to run

An air wave zone whose element is a command in `[lat,lon]cmd` form — e.g. `[0,0]-shilka` — and a QRA
zone with the same kind of element, since both branches were fixed. Deploy each and look at where the
group arrives on the F10 map.

**Expected:** inside the trigger zone, within the respawn radius of its centre.

**A result that would contradict the fix:** the group still lands away from the zone, or at an
implausible altitude. Either would mean the vec3 is right and something downstream reads it
differently — say the fix and the reading, and reopen.

## Definition of done

- [ ] An air wave with a command element spawns inside its zone
- [ ] A QRA with a command element spawns inside its zone
- [ ] The line removed from `DCS-SESSION-TODO.md` and the lot closed
