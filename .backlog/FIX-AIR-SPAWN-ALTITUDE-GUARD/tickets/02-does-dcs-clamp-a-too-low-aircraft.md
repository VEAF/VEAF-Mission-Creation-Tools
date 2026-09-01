# 02 — Does DCS lift a too-low aircraft on its own? The clearance rule depends on the answer

Status: 🧑 waiting-human — needs DCS running; written up in `DCS-SESSION-TODO.md` (item R9).
Type: question

[Ticket 01](01-read-the-altitude-not-the-easting.md) fixed the field the height test reads, which is
wrong whatever the answer here. What it deliberately did **not** decide is the threshold: today the
guard refuses a point under the terrain and nothing else.

## The question

An aircraft group spawned at, or a metre above, ground level — does DCS place it there and let it
explode, or does it lift it to a flyable altitude by itself?

Nobody in this repository can answer it without the game, and the answer decides between two different
rules. It also decides whether this was ever a **live** defect or merely a dead guard: the PRD says as
much, and the code cannot tell.

## The two forms

**Form A — what shipped.** Refuse only a point below the terrain.

```lua
if spawnPosition.y < veaf.getLandHeight(spawnPosition) then
  return false
end
```

Nothing legitimate moves: an aircraft on the ground is accepted, which is where a static one belongs.
If DCS lifts a too-low aircraft, this is the whole of the correct answer and the ticket closes as a
non-finding.

**Form B — clearance, if DCS does not lift.** The line's author wrote `10`, and the MiST-derived
spawner in this same repository already applies exactly that number:
`VeafGroupSpawn.MINIMUM_CLEARANCE_METRES = 10` (`veafDcsSpawner.lua:750`), compared against
`land.getHeight` at the point — the correct reading of the same rule, and evidence that MiST did not
trust DCS to clamp.

Two things must be settled before that form can ship, which is why it is not in this PR:

1. **What to do instead of refusing.** `veafDcsSpawner` does not refuse: it drops the aircraft into an
   altitude band above the ground (`ALTITUDE_BANDS`, 300–9000 m for a plane, 200–3000 m for a
   helicopter). Refusing means twenty-five identical redraws and then *"cannot find a suitable
   position"*, which for an altitude problem is a poor answer — the position was fine, the altitude was
   not. `checkPositionForUnit` is a boolean validator and cannot lift anything, so this form implies the
   correction happens in the callers instead.
2. **Statics must be exempt.** An aircraft placed as a static is on the ground on purpose and clears
   nothing. `checkPositionForUnit` cannot currently tell: `veafSpawn.spawnUnit` passes the unit from the
   database, whose `air` is true and whose `static` is false — the *"spawn it as a static"* decision is a
   separate parameter the function never sees. So form B needs the caller to say so, which is a
   signature change the PRD puts out of scope.

## What to run

In `DCS-SESSION-TODO.md`, item **R9**. Short version: spawn an aircraft group at an explicit low
altitude over flat terrain and look at what the game does with it — nothing to rebuild, the answer is
about DCS rather than about our scripts.
