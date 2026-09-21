# 07 — The doc's bare-aircraft example stops being true

Status: ✅ done
Type: doc

## What breaks

[`doc/mission-maker/concepts/dynamic-slots.md`](../../../doc/mission-maker/concepts/dynamic-slots.md),
section *Le piège*:

> Sur les modèles fournis par défaut, une petite minorité seulement porte un emport : un A-10C II
> sort armé et peint, un **UH-1H ou un F/A-18C sortent nus**.

Ticket 06 arms the F/A-18C. The claim becomes false the moment the graft lands, in the one page a
mission maker reads to understand why their pilots spawn with empty pylons.

The headline — *a small minority* — stays true: 33 of 128 after the graft, against 18 of 104 before.
26 % is still a minority, so the advice does not change; the example does.

## What to do

- Swap the F/A-18C for an airframe that is still bare after tickets 05 and 06 — the UH-1H stays bare,
  and there are 95 others to choose from. Pick one the reader will recognize.
- Same edit in [`dynamic-slots.en.md`](../../../doc/mission-maker/concepts/dynamic-slots.en.md).
- While in the page: it is the page that tells the mission maker to re-extract from their own mission
  (`extract-aircraft-groups --kind dynamic-template`), which is exactly the path that hit ticket 01's
  encoding defect. Nothing to add once the defect is fixed, but check the surrounding wording still
  reads true.

## Definition of Done

- Both language versions name a template that is genuinely bare in the shipped catalogue, verified
  against the file rather than assumed.
- `poetry run docs-check` green.
- No version string written into the page header (CLAUDE.md §7).
