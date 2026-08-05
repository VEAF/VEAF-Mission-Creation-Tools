# FIX-CLI-UTF8-ASK-STREAMING

Status: ✅ done

## Problem

`veaf-tools ask` returned a **truncated** answer on Windows — cut off mid-sentence.
Verified the data arrives complete (Worker SSE + Python client both yield the full
text); the cut happens in the **console rendering**.

`console = Console()` (`veaf_libs/logger.py`) inherits the terminal's encoding
(cp1252 on cmd.exe). The first glyph outside cp1252 — an arrow `→`, box-drawing from
a code block, an emoji — makes `console.print` raise `UnicodeEncodeError` **mid-render
and stop**, leaving only the text written so far. Reproduced:
`can't encode character '→'` under cp1252.

Transverse: also affects `convert-v5` reports (emojis 🗑️/⚠️/✓, arrows).

## Decisions

1. **Global UTF-8 fix**: force `sys.stdout`/`sys.stderr` to UTF-8 (`errors="replace"`)
   at CLI start, so a render always completes. Fixes `ask` and every other command.
2. **Real streaming for `ask`**: render the Markdown answer live as chunks arrive
   (rich `Live`) instead of buffering then printing once — a truncation is now visible.

## Implementation

- `veaf_libs/logger.py`: `configure_stdio_encoding()` — reconfigure both standard
  streams to UTF-8, defensive (stream without `reconfigure`, or a failure, is ignored).
  Called from the Typer `main_callback` (runtime, not at import, to keep tests clean;
  Rich resolves `sys.stdout` lazily so the existing `console` picks it up).
- `veaf_tools/commands/ask.py`: `_stream_answer` uses `rich.live.Live` +
  `vertical_overflow="visible"`; spinner until the first chunk, then live Markdown.

## Out of scope

- Console wording elsewhere; the chatbot Worker (works correctly).

---

## 01 — UTF-8 stdio + live `ask` streaming

Status: 🔄 in-progress

### Tasks

- [ ] `configure_stdio_encoding()` in `logger.py`, called from `main_callback`.
- [ ] `_stream_answer` (ask.py) → live Markdown rendering via rich `Live`.
- [ ] Tests: encoding helper (reconfigures, skips streams without it, swallows failure);
      `_stream_answer` consumes the whole stream and returns the full text.
- [ ] CHANGELOG `[Unreleased]`, PATCH bump.

### Definition of Done

- `poetry run pytest` green, coverage gate held; ruff/format/mypy clean.
