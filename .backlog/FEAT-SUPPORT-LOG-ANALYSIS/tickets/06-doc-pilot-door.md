# 06 — A door for pilots, not only mission makers

Status: ⬜ ready

Type: docs

## The problem

This lot targets *a mission maker or a pilot*. But `veaf-logs` is documented in
[`doc/mission-maker/LOGS.md`](../../../doc/mission-maker/LOGS.md) and nowhere else: a pilot with a
crashing DCS has no reason to open the mission-maker section, and will never learn the tool exists.
Half the intended audience cannot find the feature.

## What to write

- A pilot-facing entry point — a section in [`doc/pilot/GUIDE.md`](../../../doc/pilot/GUIDE.md), or
  a page of its own — saying: *DCS misbehaves, here is a tool that reads its log and explains it.*
  Written for someone who has never run a VEAF command line.
- The analysis feature documented where the tool itself is documented, including what it does
  **not** do: it explains, it does not repair, and outside the catalogue it says so.
- The link from the support page created in
  [`FEAT-SUPPORT-DIAGNOSTIC` ticket 03](../../FEAT-SUPPORT-DIAGNOSTIC/tickets/03-doc-support-page.md).

The shape of the pilot door is open question 1 of the PRD — section or standalone page is David's
call, and worth asking before writing.

## Notes

- Both languages in lockstep, both in the `nav` with their `nav_translations` entry.
- Explicit English anchors on anything linked from another page.
- PowerShell examples, `.\veaf-logs.exe`.

## Definition of done

- [ ] A pilot-facing entry point exists and is reachable from the menu, both languages
- [ ] The *Explain* and *Prepare a report* actions documented, with their limits stated
- [ ] Cross-links with the support page, both directions
- [ ] `poetry run docs-check` passes
