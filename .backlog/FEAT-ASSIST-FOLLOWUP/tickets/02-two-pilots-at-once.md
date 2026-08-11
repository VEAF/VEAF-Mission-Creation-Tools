# 02 — Two pilots at once, and whether a highlight leaks

Status: 🧑 waiting-human
Type: test

## The question, open since the parent lot's first ticket

The engine boxes a cockpit control with `a_cockpit_highlight`, reached through
`net.dostring_in("mission", …)`. **Does that box appear in a second pilot's cockpit?**

Nobody has ever had two pilots assisted at once. The engine carries a **per-session highlight id**
precisely for this, and it has never been exercised — so the mechanism is untested rather than known
broken.

## Why no test can answer it here

The DCS mocks pin *which API is called with which arguments*, not DCS's reaction. This is the same
class of question `FEAT-COMBATZONE-MENU-COALITION` had to send to the smoke harness, and that lot is
worth remembering twice over: getting its answer needed **two repairs to the check itself**, because
the first version returned a pass whenever `pcall` did not raise — a nil would have unblocked the lot
in the wrong direction.

So whatever runs here has to report **what came back**, not that nothing raised.

## Can the smoke harness do it?

Unknown, and worth establishing before asking for cockpit time: `FEAT-DCS-SMOKE-HARNESS` runs inside
one mission, and two *assisted pilots* may need two connected clients, which a harness cannot fake.

If it cannot, this is a two-human check and stays blocked on that. If a single client in two slots is
enough to expose leakage, the harness is the cheaper route by far.

## Tasks

- [ ] Establish whether the smoke harness can hold two assisted sessions at once, or whether two
      clients are genuinely required. Answer this **first** — it decides whether the rest costs a
      probe or an evening with a second pilot.
- [ ] Exercise two concurrent sessions on different aircraft, then on the same aircraft type.
- [ ] Report what `a_cockpit_highlight` did, per cockpit: box present, absent, or in the wrong one.
- [ ] If a highlight leaks: the per-session id is the intended lever — establish whether it is being
      passed and ignored, or not being passed at all.

## Acceptance criteria

- [ ] The question is answered with an observation, not an absence of error.
- [ ] The result is written into the ticket whichever way it goes — "highlights do not leak" is a
      finding worth keeping, not a non-event.

## Blocked on

David: a second pilot, or the answer to the harness question above.
