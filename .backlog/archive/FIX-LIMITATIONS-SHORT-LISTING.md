# FIX-LIMITATIONS-SHORT-LISTING — the short listing of known limitations leaves room to grow

Status: ✅ done — merged in #1156 (2026-10-20) · archived 2026-11-24

Origin: David, 2026-10-20. `describe_known_limitations` with no argument returns a short listing that must stay under 15 000 characters, so an MCP client gets it as one tool result (`test_the_default_is_a_short_listing_that_fits_a_tool_result`). Merging FEAT-AI-ZERO-SETUP with FEAT-TERRAIN-DATA-DOWNLOAD took it to 15 074; shortening four titles brought it back to 14 988, 12 characters of margin: the next limitation any lot adds breaks the test.

## Decision

The short listing drops `title` and keeps `id`, `kind`, `area` and `theatres`: measured 2026-10-20, 7 216 characters for 81 entries instead of 14 988. The ids are kebab-case phrases (`sam-without-ewr-is-lit`) that already say what an entry is about; an assistant reads the entries of its areas with `area`, or one with `id`, in full, titles included. The 15 000 cap stays.

## Tickets

- [01 — Drop `title` from the short listing](FIX-LIMITATIONS-SHORT-LISTING.md)

## Tickets, in full

## 01 — Drop `title` from the short listing

Status: ✅ done

`_LIMITATION_SUMMARY_FIELDS` in `veaf_mission_mcp/oracle.py` loses `title`; the action description, the authoring guide and `doc/developer/mission-editing-mcp.{md,en.md}` say what the short listing holds; the test asserts the fields and keeps the 15 000 cap. CHANGELOG.
