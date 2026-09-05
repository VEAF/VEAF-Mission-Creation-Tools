# 02 — The user log finally records stack traces

Status: ✅ done

Type: fix

## The problem

`veaf_libs.logger.exception(e)` calls `error(str(e), exception_type=type(e))`
([`logger.py:103`](../../../src/python/veaf-tools/veaf_libs/logger.py)) — no `exc_info`, so **the
stack trace is never written to the file**. The log records that something failed and loses the
only part that says where.

The file itself is `~/.veaf/veaf-tools.log` (or `$VEAF_HOME/veaf-tools.log`), resolved through
`get_veaf_home()` ([`logger.py:49`](../../../src/python/veaf-tools/veaf_libs/logger.py)), appended
to for ever with no rotation.

An uncaught exception is not journalled at all: `app()` is wrapped in `try/finally` with no
`except` ([`app.py:80`](../../../src/python/veaf-tools/veaf_tools/app.py)), and there is no
`sys.excepthook` anywhere in `src/python/`. The user sees a raw traceback on stderr, which scrolls
away, and the log keeps no trace of the crash that just happened.

## What changes

Three things, all in the file sink — the console output must not move:

1. `exception()` writes the traceback to the file.
2. A last-resort handler journals an uncaught exception before it reaches the terminal, so a crash
   leaves something behind for `doctor` to find.
3. Rotation, so the file that gets read back stays a sane size. Its absence is why nobody looks at
   it today.

## Why it belongs before the assistant

[Ticket 01](01-doctor-command.md) reads the last errors out of this file. Right now that returns
one-line messages with no location — which is exactly the material a support assistant cannot do
anything with either.

## Definition of done

- [x] `exception()` writes the full traceback to the log file
- [x] An uncaught exception is journalled before the process dies, and the user still sees what they
      see today on the console
- [x] Rotation in place, with a documented size and retention
- [x] Console output byte-identical to before on a representative command — asserted by a test, not
      by reading
- [x] Unit tests covering: an exception with a cause chain, an uncaught exception, and rotation
      firing
- [x] `poetry run pytest`, ruff check + format, mypy clean
