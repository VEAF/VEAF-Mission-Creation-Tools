# 03 — The commented-out engage task: deleted, with the reason

Status: ✅ done

Type: chore · Files: `src/scripts/veaf/veafSpawnAircraft.lua`

## What was wrong

A full `EngageTargetsInZone` task sat commented out inside the patrol waypoint's `ComboTask`. Twenty
lines of dead configuration that said nothing about whether the watchdog was meant to **replace** it or
to **complement** it — which is precisely the question anyone reading this code arrives with.

## The decision: deleted

It cannot complement the watchdog. The two mechanisms are incompatible by construction, on two counts:

- the group is spawned with `PROHIBIT_AA = true`, and the watchdog owns that option from then on. A
  route task telling the group to engage air targets is **inert for exactly as long as the watchdog is
  silent, and redundant the moment it speaks**;
- the watchdog undoes its own tasking through the controller's task queue — the queue this route task
  would live in. Even the narrower `popTask` this lot moved to (ticket 02) pops whatever is on top. A
  route-level engage task in that queue is something the watchdog would eventually remove without ever
  knowing it was there.

So the watchdog is the single mechanism, deliberately, and it is the one that can do what the route
task cannot: weigh targets by priority, refuse what is not an aircraft, and hand the group back its
patrol when there is nothing worth engaging.

The reason is written where the block was, not in this ticket alone — a comment in a backlog file does
not reach the next reader of `veafSpawnAircraft.lua`.

## Definition of done

- [x] The commented block is gone
- [x] The reason it is gone is in the source, at the place it was
