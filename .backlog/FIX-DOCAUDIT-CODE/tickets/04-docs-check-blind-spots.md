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

## C. `slugify` strips underscores, and mkdocs does not

Found while enumerating the anchors for `DOC-AUDIT-FIXES` 02. `docs_check.slugify` (`:98`) does
`re.sub(r"[`*_]", "", title)` — the underscore is in there with the emphasis markers, so a heading
like ``### `build_variants:` `` is registered as `buildvariants`. mkdocs keeps it: `_` is a word
character for pymdownx, and the real id is `build_variants`.

Consequence today: every underscore heading is registered under a name the site does not use, so a
**correct** link to `#build_variants` is invisible to the gate — and would be *reported* if the gate
ever checked same-page links (see D). Roughly a dozen headings in `MISSION_YAML_REFERENCE` alone.

Fix: drop `_` from that character class. Emphasis with underscores (`_text_`) is not used in these
pages; verify with a grep before assuming, and if it is, strip it with a pattern that only matches
paired markers rather than every underscore.

## D. Same-page anchors are not checked at all

The 21-entry sweep that found C also established that a **dead same-page link** (`[x](#gone)` in the
page that should contain `#gone`) passes CI untouched: the gate validates cross-page anchors only.
Seven genuinely dead ones were fixed by hand in `DOC-AUDIT-FIXES` 02 — `developer/GUIDE.md` ×4,
`veafRadio.md`, `pilot/GUIDE.md`, `TESTING.md`, each a table-of-contents entry pointing at a
heading-derived slug whose heading carries an explicit anchor.

Fix: check same-page targets with the same rule as A (explicit anchor retires the derived slug).
Land it **after** C, or the underscore bug will bury the real findings in false positives — which is
exactly what happened to a hand-rolled version of this sweep during the audit.

## Acceptance criteria

- [ ] All four rules (A-D) enforced, with tests; `poetry run docs-check` green on the repo **after** the doc
      lot's fixes (and red before, on exactly the known defects — verify that, it is the proof).
- [ ] Full Python gate green; coverage ratchet respected.

