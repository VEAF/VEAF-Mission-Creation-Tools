# 02 — a deleted issue stops being polled

Status: ⬜ ready

## The defect

`IssueWatcher.since` turns every `GitHubError` into `None`, which the relay reads as *GitHub could
not be asked this round* — transient by design, so nothing is lost when GitHub has a bad minute.
A deleted issue answers `410 Gone` for ever, so its link is polled every ten minutes for the life of
the service.

Live on 2026-09-09: `938`, `940` and `944`, three issues this bot filed and David deleted. Their
three warnings a round were the only content in the log, which is how a relay that had stopped
relaying anything at all read as a relay that was working.

## The change

`GitHubError` already carries `.status`. A `410` raises a new `IssueGone` from `since`; `_deliver`
catches it, drops the link, counts it in `dropped` and logs `relay.issue_gone` **once**.

`404` deliberately stays transient. It is the answer for a deleted issue *and* for an installation
whose access was revoked for a minute, and dropping every link the first time GitHub answered `404`
across the board is a worse failure than three warnings a round. `410` has one meaning only —
GitHub's own message is *"This issue was deleted"*.

## Tests

* a `410` on the issue drops the link and leaves the other links followed;
* a `410` from the *comments* page does the same — an issue can vanish between the two calls;
* a `500`, a `403` and a `404` still hold the link and move no cursor;
* the drop is logged once, not once a round, because there is no second round.
