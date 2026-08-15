# Lot DOC-QUALITY-GATE — the documentation gets the gate every other artifact already had

Status: ✅ done
Branch: feature/DOC-QUALITY-GATE

## Problem Statement

DOC-AUDIT-PASS found eight real documentation defects that had accumulated unnoticed — an English
page missing for months (its EN URL served French), six links returning 404 in production, anchors
left behind by a section renumbering, a page absent from every menu, a stale API signature, a
version header six patch releases old.

None of them was a filing problem, so no reorganisation would have prevented them. They were
**silent rot**: the CI gates the Lua, the Python, the coverage and the DCS artifacts, and gated
nothing in `doc/`.

David validated the three fixes proposed at the end of that audit.

## Solution

**1. A `docs-check` gate** (`veaf_build/docs_check.py`, CI job `Docs Check`). Refuses:

| Check | The defect it would have caught |
|-------|--------------------------------|
| relative `.md` link to a missing file | the six ADR links 404-ing in production |
| cross-page anchor absent from the target | the pipeline "step 4" links after renumbering to step 6 |
| cross-page anchor derived from a heading | fragile, and different in each language |
| FR page with no `.en.md` | `dcs-radio-specs` serving French on its English URL |
| FR page absent from the `nav` | `capture-airbases`, reachable only by one inline link |
| `nav` entry with no file | — |

It is **stdlib-only**, so the CI job needs no Poetry install and runs in seconds — which is what
makes it acceptable on every documentation push.

Two behaviours are pinned by tests because getting them wrong is what produced 245 false positives
during the audit, both settled by reading the published HTML: relative links are language-agnostic
(the i18n plugin rewrites them, so only a missing *target* is a defect, while anchors are checked
against the page the reader actually lands on), and `pymdownx` slugs **keep their accents**.

**2. Explicit English anchors.** The 82 cross-page links that relied on a heading-derived slug now
target explicit anchors, stamped on **both** language versions of 54 headings. The visible heading
text is untouched — French stays French, in the page and in the menu; only the anchor is English and
shared. Four slugs were replaced by short hand-picked names (`pipeline-step-3-aircraft-groups` for a
65-character one, `stylua-setup` for one that pinned a tool version).

FR↔EN heading pairing was done structurally (same level, same rank among headings of that level),
which resolved all 52 targets with no manual case.

**3. Version stamped at deploy** (`veaf_build/docs_version_stamp.py`). The repository keeps a
readable `6.11.x` range; the deploy workflow rewrites it to the shipped version on its throwaway
checkout. Deliberately **not** a CI gate: the placeholder always differs from the version, so a
check would fail on every commit. `--check` stays a local diagnostic.

The date line is stamped in the same pass — same defect ("June 2026" on a July build), same fix.

## Testing Decisions

- 17 tests on the gate, each over a miniature docs tree: one per defect kind, plus the two
  false-positive traps (accented anchor valid; EN-page anchor checked against the EN twin) and the
  exemption list.
- 11 tests on the stamper: FR/EN wording, idempotence, `--check` writes nothing, a per-module
  `**Version :**` further down a page is not touched.

## Out of Scope

- Reorganising the documentation: reported to David as unnecessary — four sections for four
  audiences is coherent, and the defects were rot, not filing.
- The 9 pre-existing ruff findings under `test/python/` (owned by CHORE-TOOLING-GATES ticket 03).
