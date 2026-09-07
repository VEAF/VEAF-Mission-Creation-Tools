# 03 — Explain: the catalogue first, ignorance admitted

Status: ✅ done

Type: feat

## The problem

A pilot or a mission maker looks at a wall of DCS log lines and cannot tell which one matters. The
tool knows more than it says: `rules.json` carries 22 known-noise patterns each with a `help` text,
13 sources and 8 native subsystem families — but that knowledge only drives colouring and hiding,
never an explanation.

## What to build

An *Explain* action on the current view. It works in two layers, and the order between them is the
whole design:

1. **The catalogue answers first.** Every entry matched by `rules.json` is rendered with its own
   verified wording, as-is. No model involved, no cost, works offline.
2. **The model puts it in context second.** It receives the bounded excerpt from
   [ticket 01](01-bounded-excerpt.md) plus the catalogue matches, and it chains: what happened
   first, what is a consequence of what, which line is the one to act on. Where the catalogue is
   silent it answers **"pattern not catalogued"** rather than proposing a cause.

The free model, through the Worker mode added in [ticket 02](02-worker-multi-client.md).

## Why the order matters

The worst failure of this feature is not silence, it is a plausible wrong answer: *"it comes from
your module X"* when it does not. The reader has no way to tell a guess from a verified fact, and
will spend his evening on it. Rendering the catalogue verbatim, and marking everything else as
uncatalogued, is what keeps the two apart on screen.

It also has to work with no network: the catalogue layer alone is a useful answer, and that is the
degraded mode.

## Notes

- The rendering must visually separate *verified catalogue text* from *model commentary*. Not a
  disclaimer at the bottom — nobody reads those — but a distinction the eye catches per block.
- VEAF entries deserve depth: the excerpt carries the VEAF source and level parsing
  (`^VEAF(-[A-Z0-9]+)?\|(?P<lvl>[A-Z])\|`) that generic DCS lines do not have.
- No network, no `logs` extra installed, empty selection: all three must produce something sane.

## Definition of done

- [x] An *Explain* action on the current view, in `veaf-logs`
- [x] Catalogue matches rendered verbatim from `rules.json`, before any model output
- [x] Model output visually distinct, and stating "not catalogued" instead of guessing
- [x] Offline degraded mode: catalogue only, no error dialog
- [x] Unit tests on the assembly and on the degraded path, with the Worker mocked
- [x] `poetry run pytest`, ruff check + format, mypy clean
- [x] `--cov-fail-under` raised to stay within ~2 points of measured coverage
