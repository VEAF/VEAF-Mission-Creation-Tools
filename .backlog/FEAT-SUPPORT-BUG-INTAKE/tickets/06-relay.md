# 06 — The answer comes back to where the user is

Status: ✅ done

Type: feat

## The debt this pays

Filing under a machine account means the reporter is subscribed to nothing. A maintainer asking
*"can you attach your `dcs.log`?"* on the issue is talking to an empty room, and the user never
learns his bug was even looked at. This is where integrations of this kind normally die: the report
travels fine, and then nobody speaks to anybody.

## What to build

- A durable link between a Discord thread and the issue it produced, surviving a restart.
- A listener for activity on those issues — new comments, labels that matter, closure — reposting
  into the originating thread, in a form a non-developer reads: who said what, and what it means for
  him.
- A tag on the thread when the issue closes, so the state is visible without opening anything.

## The direction not built

Discord → GitHub is deliberately left out. Letting a thread write comments onto a public repository
opens a write channel from a room anyone can join. If it is ever wanted, it needs its own decision
and its own guards; it is not a natural extension of this ticket.

The consequence is worth stating in the documentation: to add something to his report, the user
posts in the thread, and a maintainer carries it over. That is a manual step, and it is the accepted
cost.

## Notes

- Relaying every event turns a thread into noise. Relay what the reporter can act on or wants to
  know; ignore the rest.
- A deleted thread, an archived thread, or a user who left must not break the relay or crash the
  service.
- Bot comments must not feed back into the relay.

## Definition of done

- [x] Durable thread ↔ issue association, surviving restart
- [x] Comments and closure relayed into the originating thread, in plain language
- [x] Thread marked when the issue closes
- [x] Deleted, archived and orphaned threads handled without failure
- [x] No relay loop on the bot's own activity
- [x] Unit tests: relay of a comment, of a closure, and each degraded case
- [x] Quality gate clean

## What was built

`veaf_support_bot/relay.py`: the link store, the watcher, and the round. The Discord half is
`ClientThreadPoster`; the loop is a background task of the service.

**The thread is opened after the click and before the filing.** After, because an abandoned draft
must not leave a public thread about a report nobody filed. Before, because the issue carries the
thread's address in its body, and rewriting an issue afterwards is a second write that can fail on
its own. That also fills the `thread_url` ticket 04 left empty.

**Polling, as decided.** The App has no webhook and no events, so a webhook would have cost a public
route, a shared secret and a signature check for latency nobody is waiting on. One pair of calls per
followed issue every ten minutes sits far inside the 5000/hour an installation gets.

**The cursor is a comment id, never a timestamp.** Two comments in the same second would race, and
the symptom would be "the reporter missed the one answer that mattered". A transient failure moves
no cursor: `since` answers `None` rather than an empty state, so nothing is marked as seen.

**The anti-loop filter sits at the delivery step, not at the read.** It was written in the watcher
first, and the test that injects a state directly showed what that meant: any other producer of an
`IssueState` would have been free to feed the loop. Moved to `_deliver`, where the posting happens.

**One bad thread never ends the round.** A rate limit is retried; only a definitive *this thread no
longer exists* drops a link. A restart finds an empty Discord cache — the bot runs on
`Intents.none()` — so the poster **fetches** a thread it cannot see, which is what keeps the relay
alive across a redeploy.

## A bug this ticket found in passing

`extra={"thread": ...}` on a log line **raises** `KeyError`: `LogRecord` already owns that field.
It passed the relay's own tests, where no handler builds a record, and failed the moment the whole
suite ran with logging configured — which is to say it would have failed in production, on the line
reporting that a report had started being followed. Fixed, and `tests/test_log_fields.py` now walks
the package's syntax tree and fails on **any** `extra=` key that collides with a record field, so
the family is closed rather than this one member.
