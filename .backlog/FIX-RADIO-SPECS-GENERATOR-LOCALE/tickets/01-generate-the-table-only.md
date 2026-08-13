# 01 — Generate the table into both pages, and only the table

Status: ⬜ ready
Type: fix
Files: `veaf_build/radio_specs_updater.py`, `doc/mission-maker/dcs-radio-specs.{md,en.md}`,
`test/python/veaf_build/test_dcs_data_radio_specs.py`, `.github/workflows/dcs-data-drift.yml`

## The shape to reach

`write_markdown` currently builds a whole page and writes it to one file. It should instead
**replace a delimited block inside a page that already exists**, once per language:

```markdown
<!-- BEGIN generated: radio specs -->
| Appareil | ID DCS | Radio | Min (MHz) | Max (MHz) | Modulation |
...
<!-- END generated: radio specs -->
```

Prose outside the markers is then preserved by construction rather than by whoever remembers to
restore it.

## Read the two shipped pages before writing any code

They have drifted a long way from the generator's output, and the drift is the specification. As of
2026-08-13:

| Section | FR page | Generated? |
|---|---|---|
| Intro + source note | localised prose | generator emits its own, in English |
| `## Particularités par type — gérées automatiquement` | hand-written | no |
| `## Appareils critiques (\`dcs_rejects_on_load\`)` | hand-written | no |
| `## Fréquence principale du groupe (\`human_radio\`) {#primary-frequency}` | localised heading, explicit anchor | yes — `_primary_frequency_section` emits `## Primary-frequency limits`, **no anchor** |
| `## Avions` / `## Hélicoptères` + tables | localised headings | yes — emits `## Fixed-wing aircraft` / `## Helicopters` |

So three things need localising per language, not just the table body: the two category headings,
the primary-frequency section's heading **and its explicit `{#primary-frequency}` anchor** (which
the generator does not emit at all today, and which another page links to — dropping it would trip
`docs-check` rule A). Column headers are localised too (`Appareil` vs `Aircraft`).

Decide from the pages, not from this table: it was written by reading them once and the audit's
lesson is that a summary of a document is not the document.

## The invariant that must not break

`dcs-radio-specs` is a **hybrid artifact**. `dcs-radio-specs-overrides.yaml` carries entries the
datamine has none of (`MiG-15bis`, `MiG-15bis_FC`, the AJS-37 FM band, `dcs_rejects_on_load`,
`kneeboard_only`), and `apply_overrides` merges them into the models *before* writing. That path
already works — `FIX-DOCAUDIT-CODE` 06 verified all four override kinds survive a regeneration —
so do not touch it, and keep asserting it.

## TDD

- Failing first: run the writer against a fixture page containing prose above and below the
  markers, and assert the prose is still there afterwards, byte for byte.
- Failing first: assert the **English** page is written too — today it is never opened.
- Assert the localised headings and the `{#primary-frequency}` anchor appear on the right page each.
- A page missing its markers must **fail loudly**, not be silently skipped or overwritten whole: a
  generator that quietly does nothing is how a stale table ships.
- Regression: the four override kinds still reach both artifacts.

## Acceptance criteria

- [ ] `veaf-build update-dcs-data --radio` on a clean checkout touches only table content, in both
      languages; `git diff` shows no prose line.
- [ ] Tests cover prose survival, both-languages writing, per-language headings, the preserved
      anchor, and the missing-marker refusal.
- [ ] `docs-check` green (it was green through the whole defect, so it proves nothing here — the
      tests are the proof).
- [ ] `dcs-data-drift.yml`'s manual follow-up drops the "restore its prose sections" warning and
      says the command is now safe to run.
- [ ] Full Python gate green; coverage ratchet respected.

## Not in scope

The YAML side (`dcs-radio-specs.yaml`) is already regenerated safely and needs nothing.
