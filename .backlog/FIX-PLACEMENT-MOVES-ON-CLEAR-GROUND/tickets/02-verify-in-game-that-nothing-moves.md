# 02 — Verify in game that a FARP on open ground does not move

Status: 🧑 waiting-human
Type: verification

Nothing here can be done without DCS running. The unit tests prove the rule; only the game can say
whether `Disposition` answers the way the rule assumes, because the whole tier rests on an undocumented
singleton (ADR 0018) whose behaviour has already been measured to differ from its arguments — asked
800 m in game on 2026-08-06, it answered 2035-2258 m.

## What to run

The session mission of `DCS-SESSION-TODO.md` — Caucasus, security off — rebuilt with `--dev-mode`
against this branch so it carries the fix.

1. `-farp` on **open ground, nothing within a kilometre**. This is the non-regression case of item 21.
2. `-farp` **in or beside a wood**, so the requested spot is genuinely in the trees.
3. `-farp` **beside a static FARP**, so the requested spot is on its apron.

## What to look at

`%USERPROFILE%\Saved Games\DCS\Logs\dcs.log`, grep `FARP escort:` and `findClearBearing:`.

| Case | Expected |
|---|---|
| Open ground | `FARP escort: bearing N requested, N used at 1x distance` — the two bearings **equal**, scale 1. Plus `findClearBearing: bearing N is inside a scenery-clear area, keeping it` |
| Wood | the two bearings **differ**, and the escort is visibly out of the trees |
| Beside a static FARP | the two bearings **differ**, or the scale is above 1, and the escort is off the apron |

The middle and last rows are what make this a real check rather than a confirmation: a run where
*nothing* moves in any of the three cases means the fix went too far, and is a failure of this ticket,
not a pass.

`findClearBearing: no usable point in Disposition's cloud, walking the bearings instead` is now at
**info**, so it is readable at the default log level. If it appears in the open-ground case, the cloud
answered nothing usable and tier 2 took over — the outcome is still "nothing moves", but the reason is
not the one this lot implemented, and that is worth recording.

## What it unblocks

[`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04](../../FIX-PLACEMENT-IGNORES-SCENERY/tickets/04-refuse-the-farp-when-the-escort-cannot-be-placed.md)
requires proving *"a FARP far from anything is never refused and **nothing moves**"*. That half was
false on `develop` independently of anything ticket 04 does.

Its exhaustion measurement — `nothing clear at any bearing or distance` fired 0 times out of 4 on
2026-08-28 — is **not** disturbed by this fix, and does not need re-running: the new guard only adds an
earlier way to accept, it never makes the search harder, so a case that did not exhaust before cannot
start exhausting now. What ticket 04's `T1-DEGAGE` row records — *bearing 0 → 25, 1.12x* on open
ground — is what this ticket expects to see change.
