# 01 — a reopened issue is followed again

Status: ⬜ ready

## The defect

`Relay._deliver` pops the link right after announcing a closure. A reopening therefore reaches
nothing, and the thread the report came from stays archived and marked `✅` while the issue lives on.
Measured on #946: closed 2026-09-08 19:49, reopened 2026-09-09 07:42, **ten** human comments written
after the closure and none relayed.

## The change

* `Link` gains `closed_since` — a Unix timestamp, `0.0` when the link is not closed. The clock comes
  in as an injectable `clock` on `Relay`, the way `Quota` already takes one, so the retention is
  testable without waiting a week.
* `KEEP_CLOSED_SECONDS = 7 days`. A link seen closed for longer than that is forgotten at the top of
  the round, **before** it costs an API call. A week, because a reopening a week later is a new
  conversation; and because the budget this bounds was never close (see the PRD).
* A link that is `closed` while the issue reads `open` is a reopening: announce it (new
  `relay.reopened` text, French and English), un-mark the thread, clear `closed`/`closed_since`.
* The announcement comes **before** the comments in `_deliver`. What follows it is everything said
  on the issue while nobody was listening, and it reads backwards under a thread still marked as
  settled.
* `ThreadPoster` gains `mark_reopened`; `ClientThreadPoster` strips `CLOSED_MARK` from the thread
  name and un-archives. Like `mark_closed` it is cosmetic and never fails a round — the reopening is
  also said in words. It skips the API call entirely when there is nothing to undo: Discord allows
  only two thread renames per ten minutes.
* `Round` gains `reopened` and `forgotten`, and the round's log line reports them.

## The mark and the announcement are two things, found in the pre-PR review

The first version cleared `closed` whether or not `mark_reopened` had succeeded. Discord allows a
thread **two renames every ten minutes** and the closure already spent one, so a rename can be
refused — and after that the reopening condition can never be true again: a live thread would keep
its `✅` for ever with nothing in a position to retry. Gating the announcement on the rename instead
is worse, since a missing *Manage Threads* would then cost the reporter his messages over a cosmetic
call.

So `Link` carries `closed_marked` — *the thread currently wears the mark* — apart from `closed`,
*the issue is closed*. The rename is attempted on any round where the issue is open and the flag is
still set, it never blocks anything, and only a success clears it. `_link_of` defaults the field to
`closed` rather than to `False`, so a file written before it existed — or repaired by hand — still
gets its `✅` taken off.

## Why `closed_since` is defensive about its own value

A links file written before this ticket has no `closed_since`, and one edited by hand can hold
anything. Any value that is not a moment in the past — absent, zero, or ahead of the clock after an
NTP correction — starts the week **now** rather than expiring on sight. Forgetting a link early is
precisely the failure this ticket exists to prevent, so the ambiguous case must not resolve to it.

## Tests

* a reopening is announced, un-marks the thread, and relays what was said since;
* it is announced **once** — a second round on the same open issue says nothing;
* the announcement precedes the relayed comments;
* a link closed for less than the window survives the round and is still polled;
* a link closed for longer is forgotten, and costs no call to the watcher;
* a link with no `closed_since` is given the full window instead of being dropped;
* a refused rename keeps `closed_marked` and is retried next round, without announcing twice;
* a refused rename costs neither the announcement nor a single relayed comment;
* a closure whose own rename was refused arms no un-mark — there is nothing to take off;
* a link persisted as `closed` with no `closed_marked` still gets its `✅` removed;
* `test_a_closed_issue_stops_being_followed` becomes *stops being followed after a week*.
