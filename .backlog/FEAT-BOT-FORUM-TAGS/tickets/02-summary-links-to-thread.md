# 02 — The summary message links to the follow-up thread

Status: ✅ done
Type: feat

## Why

The ephemeral message that closes a `/bug` or a `/suggest` says what was filed and links the
**issue**. It never linked the **thread**, because the thread was three lines below it in the same
channel. Now that it is a post in a forum, nothing tells the reporter where his report went.

Asked by David on 2026-09-08, right after the first production try.

## The fix

One extra line at the end of the summary, when a thread was opened — forum or anchored, no branch
between them:

- One shared key, `filed.followup`, in French and English. Two were planned, one per flow; the
  sentence turned out to be the same in both, and a second key would only have been two ways to
  say it that could drift apart.
- Appended in `BugIntake._file` and `SuggestIntake`'s filing step, where `handle` is already in
  scope and already tested for `opened`. Only when an issue exists: a thread whose filing failed
  is told so in the thread itself, and linking to it from the summary would read as success.

The url is `ThreadHandle.url`, which the issue body already carries — nothing new to plumb.

## Tasks

- [x] The text key, both languages.
- [x] `/bug`: appended after the outcome, before the hypothesis note.
- [x] `/suggest`: appended to what `_say` renders.
- [x] Tests: the link is in the summary when a thread was opened; it is absent when none was.

## Acceptance criteria

- [x] Filing a report through `/bug` shows the thread's link in the private answer.
- [x] The same for `/suggest`.
- [x] A report filed with no thread at all shows no dangling label.
- [x] `poetry run pytest` green; ruff, ruff format, mypy clean.
