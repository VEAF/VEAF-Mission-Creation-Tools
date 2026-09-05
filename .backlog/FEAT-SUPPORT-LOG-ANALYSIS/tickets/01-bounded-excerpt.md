# 01 — A bounded, redacted excerpt out of what is on screen

Status: ✅ done

Type: feat

## The problem

An 11 MB log cannot be sent anywhere and cannot enter a model's context. But `veaf-logs` has
already done the hard part: the categories, the levels, the noise rules and the search context have
reduced the file to the handful of lines the user is looking at. Nothing turns that view into a
transmissible artefact — the tool exports nothing at all today, its only outputs being `Ctrl+C` and
`Ctrl+Shift+C` to the clipboard.

## What to build

A single function, used by the three tickets that follow: *from the current view, produce a bounded,
redacted, structured excerpt.*

- **Bounded**: a hard ceiling in characters, applied after selection, with the drop made visible
  (`… 412 lines omitted …`) rather than silent.
- **Structured**: each entry keeps its timestamp, source, level and subsystem — the model needs the
  shape, and so does a human reading the issue later.
- **Redacted**: the helper from
  [`FEAT-SUPPORT-DIAGNOSTIC` ticket 01](../../FEAT-SUPPORT-DIAGNOSTIC/tickets/01-doctor-command.md),
  applied here rather than reimplemented. Windows user paths, addresses, tokens.
- **Honest about what was hidden**: the excerpt states which categories were excluded, so nobody
  concludes from silence. A log filtered down to "no errors" because the user unticked ERROR must
  not read as a clean log.

## The trap next door

Context lines pulled in around a hit must not resurrect entries the categories set to ✕ — the
defect `FEAT-VEAF-LOGS-READABILITY` had to solve for search. The excerpt builder sits downstream of
the same machinery and inherits the same obligation.

## Definition of done

- [x] One entry point producing the excerpt from the current view state
- [x] Ceiling enforced, omissions stated in the output
- [x] Redaction applied, asserted on a Windows user path, an IPv4 address and a token-shaped string
- [x] Excluded categories declared in the excerpt header
- [x] Context lines never reintroduce an excluded category — asserted by a test that fails if the
      guard is removed
- [x] Unit tests on a synthetic log fixture, no GUI needed
- [x] `poetry run pytest`, ruff check + format, mypy clean
