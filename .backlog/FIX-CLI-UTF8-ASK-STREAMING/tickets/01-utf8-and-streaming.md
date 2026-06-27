# 01 — UTF-8 stdio + live `ask` streaming

Status: 🔄 in-progress

## Tasks

- [ ] `configure_stdio_encoding()` in `logger.py`, called from `main_callback`.
- [ ] `_stream_answer` (ask.py) → live Markdown rendering via rich `Live`.
- [ ] Tests: encoding helper (reconfigures, skips streams without it, swallows failure);
      `_stream_answer` consumes the whole stream and returns the full text.
- [ ] CHANGELOG `[Unreleased]`, PATCH bump.

## Definition of Done

- `poetry run pytest` green, coverage gate held; ruff/format/mypy clean.
