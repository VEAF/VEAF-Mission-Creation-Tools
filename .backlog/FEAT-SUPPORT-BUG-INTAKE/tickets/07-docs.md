# 07 — Say what the machine wrote, and what it guessed

Status: ⬜ ready

Type: docs

## What to write

**For users**, on the support page: what `/bug` does, that files are read and filtered, that
personal data is stripped before publication, that nothing is published before they click, that the
issue is filed by a bot on their behalf, and that answers come back into the thread. Also the manual
step: to add something later, post in the thread.

**For maintainers**, next to the service: how to read a machine-filed issue — which parts are facts,
which part is a guess — how the prior-art sweep decided what it decided, and how to disable the
agent flow if the shared quota runs short.

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

- [ ] User-facing section on the support page, both languages, covering the privacy and consent
      steps explicitly
- [ ] Maintainer documentation next to the service, including how to switch the paid flow off
- [ ] `CONTRIBUTING.md` intake section updated
- [ ] The "hypothesis is a guess" line stated in both the user and maintainer documents
- [ ] `poetry run docs-check` passes
