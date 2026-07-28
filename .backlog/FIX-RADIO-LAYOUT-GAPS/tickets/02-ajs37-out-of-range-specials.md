# 02 — AJS-37: two trailing specials below the radio's floor

Status: ⬜ ready
Type: fix

## Why

See the [PRD](../PRD.md), gap 2. The `AJS37` layout declares `{freq: 33, mod: 1, label: E}` and
`{freq: 34, mod: 1, label: F}` among its `trailing_specials`, while the specs give the aircraft
one radio spanning `103.0–400.0 MHz`. Both are dropped as out of range on every build, reported
as channels 44/45.

## Two possible truths — establish which before editing

1. **The specials are wrong** → correct or remove them from `dcs-radio-layouts.yaml`.
2. **The specs are incomplete** → the real AJS-37 carries an **FR24** FM radio alongside the
   FR22; if the datamine omits it, 33/34 MHz are legitimate FM channels on a radio the specs do
   not know about, and the fix belongs in the specs (or in a layout entry describing the second
   radio).

ADR 0010 cites the AJS-37's "leading dummy + hardcoded specials + per-channel modulations" as the
motivating hard case, and `mod: 1` on both entries says the author meant FM — which points at
truth 2, and likely shares a root with gap 3.

## Tasks

- [ ] Check the AJS-37's actual radio fit (FR22 V/UHF, FR24 FM) against `dcs-radio-specs.yaml`,
      and state plainly which truth holds.
- [ ] Apply the corresponding fix; if it is the specs, say whether the generator or the datamine
      is at fault.
- [ ] Rebuild and confirm channels 44/45 leave the report.
- [ ] Keep the priority-driven specials (`Sp1`/`Sp2`/`Sp3`/`H`) working — they are the reason
      `priority` exists on a channel (ADR 0012).
- [ ] CHANGELOG.
