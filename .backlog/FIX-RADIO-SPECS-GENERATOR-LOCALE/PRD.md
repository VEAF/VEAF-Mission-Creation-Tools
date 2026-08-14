# FIX-RADIO-SPECS-GENERATOR-LOCALE — the radio-specs generator writes its English page over the French one

Status: ✅ done — 2026-08-13

Origin: `FIX-DOCAUDIT-CODE` ticket 06, which had to merge a single table column by hand because the
generator cannot be run. Recorded there as an observation, promoted to a lot on David's call
(2026-08-13).

## The defect

`veaf_build/radio_specs_updater.py` names one Markdown output:

```python
OUTPUT_MD = Path(__file__).parent.parent / "doc/mission-maker/dcs-radio-specs.md"
```

That is the **French** page — the site's default locale — and `write_markdown` writes the *whole
page*, in English. `dcs-radio-specs.en.md` is never written at all. So
`veaf-build update-dcs-data --radio` does three things at once:

| | |
|---|---|
| The FR page | 100 lines replaced by 84. The title becomes *DCS Radio Frequency Specifications*, and every hand-written prose section goes: per-type quirks, the Mi-24P's channel 0, the OH-58D's reserved M/C slots, the Viggen's FR22/FR24 specials, the links to `PIPELINE_REFERENCE` and to the developer projection page |
| The EN page | untouched, therefore stale against the FR one |
| `docs-check` | **green** — measured on 2026-08-13 by actually overwriting the page |

That last row is the reason this is a lot rather than a note. The gate has no way to express "a
French page now holds English text": the file exists, its links resolve, its twin exists, it is in
the nav. It is the same family as everything the documentation audit found — the gate cannot see
content.

## What already protects it, and why that is not enough

`dcs-data-drift.yml` tells whoever opens the post-DCS-patch issue exactly what to do:

> the generator writes the whole French page in English, so restore its prose sections and re-add
> the changed table rows to both `.md` and `.en.md` by hand

So the command is never run automatically, and the person running it has the instruction in front
of them. The residual risk is narrow and real: it has to be done correctly by hand, across two
pages, and **nothing catches the omission**. `FIX-DOCAUDIT-CODE` 06 walked that path — generate
into a temp dir, diff, carry 72 rows into each page with a throwaway script — and the reason it
worked is that the diff happened to be one column. A pin bump that also changed a radio's ranges
would need real judgement, on a page whose prose was being destroyed in the same run.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Generate the table into both pages, and only the table](tickets/01-generate-the-table-only.md) | ✅ |

## Definition of Done

- `veaf-build update-dcs-data --radio` can be run on a clean checkout and leaves both pages
  correct — French prose intact, English page updated — with the only diff being table content.
- A test proves prose survives a regeneration. The manual instruction cannot promise that, which is
  the whole point of the lot.
- `dcs-data-drift.yml`'s manual follow-up paragraph loses the warning it no longer needs.
- Full Python gate green; `docs-check` green; coverage ratchet respected.

## What reading the pages changed in the plan

The ticket assumed the generator's primary-frequency section was one of the blocks to localise. It is
not: **that table appears in neither page** (0 occurrences of `Primary min`). Both pages carry a
hand-written `human_radio` explanation instead — richer than the generated one, with the FW-190A8
worked through, the editor's error message and a YAML example — and the generated table had simply
been dropped when the pages were written by hand.

So the generated surface was **the two aircraft tables and nothing else**, and the plan had two
options: stop generating the primary table, or give it a home. It got a home — a second block under
the hand-written explanation — because the exhaustive list of restricted aircraft is the one part a
mission maker cannot write themselves, and it was missing from the documentation entirely. The prose
explains; the table lists.

A **third** block came out of the first run: the source note carries the pinned datamine ref, so it
has to be generated, and leaving it inside the tables block put the provenance in the middle of the
page — and produced two source notes per page on the first attempt. It is now its own block at the
top. The French one also cited `poetry run update-radio-specs`, a command that no longer exists,
which is exactly the rot a generated note prevents.

## Verification that matters

`veaf-build update-dcs-data --radio` was **actually run**, twice, on a clean checkout. Final diff:
**73 insertions, 2 deletions** on the French page and 72/2 on the English one — the insertions are the
new primary-frequency tables, and the 2 deletions per page are the stale hand-written source note
replaced by the generated one. **Not one line of prose was lost**, which is what the old generator
destroyed 100 of.
