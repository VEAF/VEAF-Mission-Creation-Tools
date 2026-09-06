# 07 — Say what the machine wrote, and what it guessed

Status: ✅ done

Type: docs

## What to write

**For users**, on the support page: what `/bug` does, that files are read and filtered, that personal
data is stripped before publication, that nothing is filed before they click, that the issue is filed
by a bot on their behalf, and that answers come back into the thread. Say plainly that the **automatic
hypothesis is a members' extra** and that its absence takes nothing away from the report — otherwise
its absence reads as a failure. Also the manual
step: to add something later, post in the thread.

**For maintainers**, next to the service: how to read a machine-filed issue — which parts are
measured and which part is a guess — how the prior-art sweep decided what it decided, which Discord
role gates the enrichment, and how to switch the enrichment off entirely without touching the intake.

**In `CONTRIBUTING.md`**: the intake circuit gains a path. Today it says to pick a template; it
should also say that a report can arrive through Discord and what that changes for triage.

## The line to hold

An automatic hypothesis is a hypothesis. The documentation says so plainly, so nobody three months
later reads a machine guess as a diagnosis and closes a real bug on it. That is the risk the whole
labelling scheme exists to contain, and documentation is half of it.

## Notes

- Both languages in lockstep, in the `nav` with their `nav_translations` entry.
- Explicit English anchors on cross-linked sections.
- `poetry run docs-check` is the gate.

## Definition of done

- [x] User-facing section on the support page, both languages, covering the privacy and consent
      steps explicitly
- [x] Maintainer documentation next to the service, including how to switch the paid flow off
- [x] `CONTRIBUTING.md` intake section updated
- [x] The "hypothesis is a guess" line stated in both the user and maintainer documents
- [x] `poetry run docs-check` passes

## What was written

**For users** — `doc/SUPPORT.md` and `.en.md` gain a `/bug` section under an explicit `{#bug}`
anchor: what the form asks, what the bot makes of it *without any AI*, that nothing is published
before the click, that personal data is stripped and that a filter which cannot run publishes
nothing. It also states the one thing the filter does not catch — **what the reporter types
himself**, including his own name in a field or in a mission's file name — because a promise of
privacy that quietly has a hole is worse than no promise.

The stale paragraph went with it: the `/ask` page said the bot could not open an issue. It now
points at the escalation button.

**For maintainers** — the service's `README.md` grew alongside each ticket rather than in one pass
at the end: how the click works, how to read a machine-filed issue, which role gates the hypothesis
and how to switch it off (leave `SUPPORT_BOT_ENRICH_ROLE_ID` empty), how the relay polls and what it
does not do.

**In `CONTRIBUTING.md`** — the intake desk now has two doors, and a section on triaging an issue a
bot filed: the body is measured, the ⚠️ comment is a guess, **the reporter is on Discord** and is
reached by answering on the issue, and the attachments are described rather than attached.

## The line held

"The hypothesis is a guess" is stated in four places — the issue's own comment, the sentence the
reporter reads, the user documentation and the maintainer documentation. That is deliberate
repetition: the risk it contains is somebody three months from now reading a machine's guess as a
diagnosis and closing a real bug on it.
