# 03 — Tell people what a suggestion becomes

Status: ✅ done

Type: docs

## What to write

**For users**, on the support page: `/suggest` exists, it first checks whether the thing already
exists, and an issue is only opened when it does not. Say plainly what happens next — an issue is a
report, not a commitment; `CONTRIBUTING.md` already states that an issue has exactly two futures,
picked up in a lot or left open as a report. Someone whose idea sits open for a year should have
read that beforehand.

**For maintainers**: how to tell a machine-filed suggestion from a hand-written one, and what the
prior-art section of the body means.

## The expectation to set

The honest framing is the one the session settled on: David alone decides, so a suggestion is
recorded, not queued. Saying it up front costs nothing and prevents the silent-tracker
disappointment that kills contribution.

## Open question to close here

Whether machine-filed suggestions carry a distinct label so they can be swept later — open question
1 of the PRD. Whatever is decided goes in this page, so the vocabulary is documented where triage
happens.

## Notes

- Both languages in lockstep, in the `nav` with their `nav_translations` entry.
- Explicit English anchors on cross-linked sections.

## The label decision

**No distinct label** (decided 2026-09-06 with David). `enhancement` + `filed-by-bot` already
isolates machine-filed suggestions exactly, and a third term would be vocabulary to maintain for a
filter anyone can write. Recorded in `docs/agents/triage-labels.md`, where triage happens.

## Definition of done

- [x] User-facing section on the support page, both languages
- [x] The "an issue is a report, not a commitment" expectation stated
- [x] Maintainer note on reading a machine-filed suggestion
- [x] The label decision recorded, and reflected in `docs/agents/triage-labels.md`
- [x] `poetry run docs-check` passes
