# FIX-LIMITATIONS-SHORT-LISTING — the short listing of known limitations leaves room to grow

Status: ✅ done — merged in #1156 (2026-10-20)

Origin: David, 2026-10-20. `describe_known_limitations` with no argument returns a short listing that must stay under 15 000 characters, so an MCP client gets it as one tool result (`test_the_default_is_a_short_listing_that_fits_a_tool_result`). Merging FEAT-AI-ZERO-SETUP with FEAT-TERRAIN-DATA-DOWNLOAD took it to 15 074; shortening four titles brought it back to 14 988, 12 characters of margin: the next limitation any lot adds breaks the test.

## Decision

The short listing drops `title` and keeps `id`, `kind`, `area` and `theatres`: measured 2026-10-20, 7 216 characters for 81 entries instead of 14 988. The ids are kebab-case phrases (`sam-without-ewr-is-lit`) that already say what an entry is about; an assistant reads the entries of its areas with `area`, or one with `id`, in full, titles included. The 15 000 cap stays.

## Tickets

- [01 — Drop `title` from the short listing](tickets/01-drop-title.md)
