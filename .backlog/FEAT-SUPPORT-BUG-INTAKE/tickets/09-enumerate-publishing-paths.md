# 09 — Enumerate every path that publishes, instead of testing a few

Status: ✅ done

Type: chore

## Why this exists

Four leaks of personal data reached review across three PRs of this lot, and every one of them took
a path the hostile fixture did not carry:

| PR | The path | What escaped |
|---|---|---|
| #919 | archive member listing | `C:/Users/Firstname Lastname/…` from a `~mis*.zip` |
| #919 | a parser's error message | a fragment of the `.miz`, briefing prose one offset away |
| #919 | the attachment's filename | the reporter's own name |
| #920 | the attachment's **bytes**, carried into a comment | account name and e-mail address, verbatim |
| #920 | the reason published when redaction fails | the host's checkout path — the server's topography |

Each time the module header promised to *"redact every text artefact"*. Each time one caller did
not. And each fix added one more case to the fixture — which is testing the leaks we already found,
not the ones we have not.

This is the repository's own lesson, already written down after a different sweep: **enumerate the
family from the code, do not sample it by hand.** Thirteen hand-picked cases once made a whole
family look fixed while three members were still broken.

## What to build

A test that **derives** the list of publishing paths from the code rather than restating it, and
asserts that each one is redacted. Something along the lines of: every call that reaches the GitHub
transport, or every function whose return value ends up in an issue body, a comment or a label —
found by walking the module, not by listing names in the test.

Two properties matter more than the mechanism:

- **It fails when a new path is added without redaction.** That is the whole point; a test that only
  covers today's callers repeats the problem it is meant to end.
- **It says which path is unguarded**, not merely that something is.

The assertion belongs on the content that reaches the **transport**, not on a function's return
value — #920's leak was at an argument of the network call, and a test on the return value would
have passed beside it.

## Notes

- `attachments.py`, `issue_body.py`, `filing.py` and `priorart.py` are the modules that publish
  today. The point of the ticket is that this list must not live in the test.
- Fail closed everywhere: redaction unavailable means the content is withheld, never published raw.
  Two paths already do this (`safe_redact`, `_publishable`); the test should confirm all of them do.
- This is worth doing once the lot's features are in, not in the middle — it is a net, not a feature.

## Definition of done

- [x] A test that derives the publishing paths from the code
- [x] It fails when a path is added without redaction — proved by adding one
- [x] It names the offending path in its failure message
- [x] The assertion sits on what reaches the transport
- [x] Every existing path passes, or is fixed
- [x] Quality gate clean

## What was built, and why it is not only a test

The ticket asked for a net. Writing one made it obvious that the net could not hold on its own: any
test that enumerates *callers* is still a test of the callers we have, and the four leaks were all
callers that believed somebody else had redacted.

So the redaction moved **under** them. `GitHubApp` now redacts every outgoing body — recursively,
strings only, non-strings untouched — on its way to the transport, and refuses to send anything when
redaction cannot run. There is no way to reach GitHub that does not pass through it, which makes the
property structural rather than remembered. Callers keep redacting what they *quote*, for their own
bounds and their own wording; this is the floor under all of them, and applying it twice is
harmless.

`tests/test_publishing_paths.py` then asserts two things, neither of which is a list of names:

1. what reaches the **transport** is redacted — asserted on the bytes handed to it, because #920's
   leak was at an argument of the network call and a test on a return value passes right beside it;
2. **nothing reaches a network any other way** — a syntax walk over the package flags any call
   carrying a body (`json=`/`data=`) outside the two clients, naming the file and the line.

The walk is put on trial: a module that posts to a network is written to a temporary directory and
the same walk must flag it, by name. It is written outside the package on purpose — a test that
leaves a landmine in the shipped tree is worse than the hole it guards.

Two smaller decisions, both from the leaks already found: the refusal message names **no path of its
own** (the reason published when redaction failed leaked the host's checkout path in #920), and a
deployment with no checkout gets a redactor that raises rather than a passthrough.