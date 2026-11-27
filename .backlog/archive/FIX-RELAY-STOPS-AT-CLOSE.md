# FIX-RELAY-STOPS-AT-CLOSE — closing an issue unsubscribes its reporter for good

Status: ✅ done — tickets 01–02 merged; 03 🚫 (the repair was no longer worth running, see the ticket) · archived 2026-11-24

Origin: David, 2026-09-09. The bot had relayed nothing to Discord for a day and its log showed only
a heartbeat and three `relay.poll_failed` warnings. Both halves of that are bugs, and neither is the
one the log points at.

## What happened

Issue [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946) was closed on
2026-09-08 at 19:49 and **reopened** on 2026-09-09 at 07:42. `Relay._deliver` drops the link the
moment it announces a closure — deliberately, to bound how many issues a round polls — so the
reopening reached a relay that no longer knew the issue existed. Ten human comments were written on
that issue afterwards (six from Tripack, four from David) and **not one reached the thread the
report came from**. The reporter's own view of it is a thread that was archived, marked `✅` and
then went silent while the conversation carried on somewhere he cannot see.

The `relay.closed` message says *"Si ton problème persiste, dis-le ici — un mainteneur pourra le
rouvrir"*, and the code comment above the drop leans on exactly that promise. It does not hold: a
maintainer reopening the issue is the normal way that sentence is answered, and it is the one action
that silences the thread for ever.

## Why the drop was there, and what it actually costs to keep

At two API calls per link per round and a round every ten minutes, a link spends **12 calls an
hour** against the 5000 an hour a GitHub App installation gets — a ceiling of about 400 links. The
service files a handful of reports a week, so keeping a closed link for a week costs on the order of
ten links, a fortieth of that allowance. The drop was protecting a budget that was never in danger,
against a failure — a link kept for ever — that a retention window prevents just as well.

## The second bug: the log was full and said nothing

`938`, `940` and `944` are issues this bot filed and David then **deleted** on GitHub.
`IssueWatcher.since` folds every `GitHubError` into "GitHub could not be asked", which is a
*transient* answer: the cursor holds, nothing is dropped, the next round tries again. A `410 Gone`
is not transient. Those three links will be polled every ten minutes for as long as the service
runs, and their warnings are the only thing in the log — which is why a relay that had stopped
relaying looked, at a glance, like a relay that was working.

## Tickets

| # | Ticket | What it is |
|---|--------|------------|
| 01 | [a reopened issue is followed again](FIX-RELAY-STOPS-AT-CLOSE.md) | keep the closed link for a week, announce the reopening, un-mark the thread |
| 02 | [a deleted issue stops being polled](FIX-RELAY-STOPS-AT-CLOSE.md) | `410` is definitive; drop the link and say so once |
| 03 | [put #946 back in the relay](FIX-RELAY-STOPS-AT-CLOSE.md) | the repair for the live link, and the procedure written down |

## Definition of done

* A reopening is announced in the thread, the `✅` and the archive are undone, and the comments
  written while nobody was listening are relayed.
* A deleted issue is dropped once, with one log line, and never polled again.
* ~~#946 is followed again and its ten missing comments have reached Tripack's thread.~~ Dropped
  2026-10-03: by then the issue was closed again and Tripack had followed it on GitHub (ticket 03).
* The README says how to repair a link by hand, because the state file is the only place that
  knowledge lives.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**closing a support issue unsubscribes its reporter for good**, found by David on 2026-09-09 from a bot log that showed a heartbeat and three warnings and nothing else. Both halves were bugs and neither was the one the log pointed at. [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946) was closed one evening and **reopened** the next morning; the relay drops the Discord ↔ GitHub link the moment it announces a closure, so the reopening reached a relay that no longer knew the issue existed and **ten** human comments were written into a thread that had been archived, marked `✅` and left silent. The `relay.closed` message invites the reporter to say so if his problem persists and a maintainer answers that by reopening — so the one action that sentence asks for was the one that cut the channel. The drop was protecting a budget never in danger: at 12 calls an hour per link against 5000, keeping closed links a week costs about ten of a 400-link ceiling, so the window now holds the bound. Second bug, and the reason the first was invisible: `938`, `940` and `944` are issues the bot filed and David **deleted**, and every `GitHubError` was transient — so a `410 Gone` was retried every ten minutes for ever, and those three warnings were the only thing in the log of a relay that had stopped relaying. `404` deliberately stays transient (it is also a permission lost for a minute; dropping every link over that is worse). Third ticket is the live repair, which needs the state volume on the VEAF Docker host — the thread id is recoverable from the issue body, and the procedure is now in the bot's README so it is not rediscovered next time

## Tickets, in full

## 01 — a reopened issue is followed again

Status: ✅ done

### The defect

`Relay._deliver` pops the link right after announcing a closure. A reopening therefore reaches
nothing, and the thread the report came from stays archived and marked `✅` while the issue lives on.
Measured on #946: closed 2026-09-08 19:49, reopened 2026-09-09 07:42, **ten** human comments written
after the closure and none relayed.

### The change

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

### The mark and the announcement are two things, found in the pre-PR review

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

### Why `closed_since` is defensive about its own value

A links file written before this ticket has no `closed_since`, and one edited by hand can hold
anything. Any value that is not a moment in the past — absent, zero, or ahead of the clock after an
NTP correction — starts the week **now** rather than expiring on sight. Forgetting a link early is
precisely the failure this ticket exists to prevent, so the ambiguous case must not resolve to it.

### Tests

* a reopening is announced, un-marks the thread, and relays what was said since;
* it is announced **once** — a second round on the same open issue says nothing;
* the announcement precedes the relayed comments;
* a link closed for less than the window survives the round and is still polled;
* a link closed for longer is forgotten, and costs no call to the watcher — asserted **inside**
  `TestTheRoundDoesNotGrowForEver`, the class review note 75 created, because the bound it names has
  changed shape rather than gone away and that class is where a reader looks for it;
* a link with no `closed_since` is given the full window instead of being dropped;
* a refused rename keeps `closed_marked` and is retried next round, without announcing twice;
* a refused rename costs neither the announcement nor a single relayed comment;
* a closure whose own rename was refused arms no un-mark — there is nothing to take off;
* a link persisted as `closed` with no `closed_marked` still gets its `✅` removed;
* `test_a_closed_issue_stops_being_followed` becomes *stops being followed after a week*.

## 02 — a deleted issue stops being polled

Status: ✅ done

### The defect

`IssueWatcher.since` turns every `GitHubError` into `None`, which the relay reads as *GitHub could
not be asked this round* — transient by design, so nothing is lost when GitHub has a bad minute.
A deleted issue answers `410 Gone` for ever, so its link is polled every ten minutes for the life of
the service.

Live on 2026-09-09: `938`, `940` and `944`, three issues this bot filed and David deleted. Their
three warnings a round were the only content in the log, which is how a relay that had stopped
relaying anything at all read as a relay that was working.

### The change

`GitHubError` already carries `.status`. A `410` raises a new `IssueGone` from `since`; `_deliver`
catches it, drops the link, counts it in `dropped` and logs `relay.issue_gone` **once**.

`404` deliberately stays transient. It is the answer for a deleted issue *and* for an installation
whose access was revoked for a minute, and dropping every link the first time GitHub answered `404`
across the board is a worse failure than three warnings a round. `410` has one meaning only —
GitHub's own message is *"This issue was deleted"*.

### Tests

* a `410` on the issue drops the link and leaves the other links followed;
* a `410` from the *comments* page does the same — an issue can vanish between the two calls;
* a `500`, a `403` and a `404` still hold the link and move no cursor;
* the drop is logged once, not once a round, because there is no second round.

## 03 — put #946 back in the relay

Status: 🚫 wontfix — 2026-10-03, David: when it could finally be run, #946 had been closed again for
24 days (reopened 2026-09-09 07:41, closed 21:15) and six of the twelve missing comments were Tripack's
own, written on GitHub where he followed the whole discussion. Replaying them would have echoed his own
words into his thread three weeks late. The link is left lost (the live file, read on the host, follows
##953 and #989 only); the procedure was already in the bot's README, which now also says when not to run
it.

The code fix does not repair the live link: #946's entry is already gone from
`/app/state/relay-links.json`, and nothing recreates it. This is the one-off repair, plus the
procedure written down so the next operator does not have to rediscover it.

### Where the thread id comes from

The thread is not lost: the issue body carries its address, which is what `filing.py` puts there.
On #946 it reads `discord.com/channels/471061487662792715/1546930226301509713` — the first number is
the guild, the second **is** the thread. `channel_id` is the forum channel from the service's own
configuration (`1545700692713537656`); `post_to_thread` never reads it, it is kept so a cold cache
can still resolve the thread after a restart.

### The entry

```json
{
  "issue": 946,
  "channel_id": 1545700692713537656,
  "thread_id": 1546930226301509713,
  "lang": "fr",
  "last_comment_id": 5590879617,
  "closed": true,
  "closed_since": 1788896964.0
}
```

`last_comment_id` is David's comment of 2026-09-08 19:46:32 — the last one the relay actually
carried over before it announced the closure. Everything after it is the backlog, and David asked
for it to reach the thread: ten comments, five a round, so two rounds and a `relay.more` notice
between them.

`closed: true` is deliberate and does the rest of the work. The issue reads `open`, so ticket 01's
reopening branch fires on the first round: the thread is told the issue was reopened, the `✅` comes
off its name, it is un-archived, and only then do the ten comments arrive. Writing `false` here
would leave a thread still named `✅` and archived, quietly filling with messages.

`closed_since` is the real closure moment, 2026-09-08 19:49:24 UTC. It is one day inside the
seven-day window, so the link survives; a stale value here would have the round forget it again on
the spot.

### The procedure

The service rewrites the whole file at every link of every round, and runs as uid 10001, so the edit
happens with the container **stopped** and through a throwaway root container on the same volume —
not `docker cp`, which would leave the file owned by root and unwritable by the service.

1. `docker inspect veaf-support-bot --format '{{range .Mounts}}{{.Name}} {{.Destination}}{{"\n"}}{{end}}'`
   to get the state volume's real name (the Compose project prefixes it).
2. `docker compose stop`
3. Run an `alpine` container with that volume on `/state`, edit `relay-links.json`: add the entry
   above, and remove `938`, `940` and `944` while there — ticket 02 would drop them on its own, but
   the file is open anyway.
4. `chown 10001:10001 /state/relay-links.json` in that same container.
5. `docker compose up -d`, then check the next round: `relay.round` with `reopened: 1`.

### Definition of done

* the thread carries the reopening notice, has lost its `✅` and is un-archived;
* the ten comments have arrived, in order;
* `relay-links.json` holds one entry, `946`;
* the procedure is in `services/support-bot/README.md`, under the relay section.

### Blocked on

David: the state volume lives on the VEAF Docker host, which this session cannot reach. Steps 1–5
are his to run.
