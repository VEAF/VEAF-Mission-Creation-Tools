# 04 — Forty pages still name the flat commands

Status: ⬜ ready
Type: docs
Files: `doc/**`, `plugin/README.md`, `veaf_build/docs_check.py`

## Measured

40 pages under `doc/` cite `veaf-tools <command>`. Every one of them keeps working — that is the
point of the hidden aliases — so nothing here is urgent. It is a consistency job: leaving the flat
form in the documentation while the tool shows a tree circulates two mental models, which is exactly
the reason decision (a) put the tree in the CLI in the first place.

## Tasks

- [ ] Rewrite the invocations to the grouped form, French and English together, page by page.
- [ ] Say once, in the CLI reference, that the flat names still work and are deprecated — a reader
      arriving from an old forum post needs that sentence to exist.
- [ ] Add a `CoverageRule` for CLI commands to `docs_check.py:231`: every name the tree defines must
      be mentioned by the CLI reference page. The mechanism is already there for MCP actions and
      marker aliases; this is a third rule, and it is what stops the next command from shipping
      undocumented.
- [ ] `poetry run docs-check` green.

## Watch out

`.claude/memory/` and `docs/` (agent-facing, not the published site) also cite command names. They
are not user documentation and are **not** in scope — but check whether any of them would mislead an
agent into writing a broken invocation, and fix only those.
