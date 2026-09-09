# FIX-RELAY-STOPS-AT-CLOSE — closing an issue unsubscribes its reporter for good

Status: 🧑 waiting-human

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
| 01 | [a reopened issue is followed again](tickets/01-reopened-issue-is-followed-again.md) | keep the closed link for a week, announce the reopening, un-mark the thread |
| 02 | [a deleted issue stops being polled](tickets/02-deleted-issue-stops-being-polled.md) | `410` is definitive; drop the link and say so once |
| 03 | [put #946 back in the relay](tickets/03-put-946-back-in-the-relay.md) | the repair for the live link, and the procedure written down |

## Definition of done

* A reopening is announced in the thread, the `✅` and the archive are undone, and the comments
  written while nobody was listening are relayed.
* A deleted issue is dropped once, with one log line, and never polled again.
* #946 is followed again and its ten missing comments have reached Tripack's thread.
* The README says how to repair a link by hand, because the state file is the only place that
  knowledge lives.
