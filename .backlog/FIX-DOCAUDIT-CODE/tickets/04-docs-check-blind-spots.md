# 04 — Harden the two `docs-check` blind spots the audit proved

Status: ⬜ ready
Type: fix
Files: `veaf_build/docs_check.py`, `test/python/veaf_build/`

Both holes are proven by survivors, not hypothesised.

## A. An explicit anchor must retire the heading-derived slug

`anchors_of()` (`docs_check.py:117-119`) registers **both** the explicit `{#anchor}` and the slug
derived from the heading text. mkdocs' `attr_list` behaviour is that the explicit anchor
**replaces** the generated id — so a link to the heading-derived slug 404s on the site while the
gate validates it. Five dead anchors survived exactly this way (`TESTING.md:9` `#couverture` vs
`{#coverage}` is the cleanest specimen).

Fix: when a heading carries an explicit anchor, register **only** the explicit one. Expect the gate
to turn red on the five known survivors if `DOC-AUDIT-FIXES` 02 has not landed yet — red pointing at
real defects is the gate working.

## B. CLI coverage must key on options, not just command names

`check_doc_coverage` requires each command's **name** to appear in its reference page — so
`capture-map --parking` shipped 2026-08-12 with zero documentation and a green gate. Extend the
rule: for each typer command, every declared option's long name (`--parking`) must appear in the
reference page too. Source the option inventory from the typer signatures at check time (import or
AST — pick what the existing check already does for command names and stay consistent).

Sequencing: land with or before `DOC-AUDIT-FIXES` 04 (the full CLI reference) — the hardened rule is
what keeps that page honest when the 26th command arrives.

## TDD

- Failing first, A: a fixture page pair where a heading carries `{#explicit}` and a link targets
  the derived slug — must be reported.
- Failing first, B: a fixture command with an option absent from its reference page — must be
  reported; the option present — green.

## Acceptance criteria

- [ ] Both rules enforced, with tests; `poetry run docs-check` green on the repo **after** the doc
      lot's fixes (and red before, on exactly the known defects — verify that, it is the proof).
- [ ] Full Python gate green; coverage ratchet respected.
