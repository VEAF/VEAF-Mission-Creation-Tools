# 02 — AJS-37: two trailing specials below the radio's floor

Status: 🧑 waiting-human — the measurement narrows it to one question for David
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


## Measured 2026-08-08 — the FR24 is absent upstream, so this is a data decision

Parsed the AJS-37 straight out of the pinned datamine: it declares **one** radio,
`Radio frequencies`, `103.0–400.0 MHz AM/FM`. The shipped specs carry exactly that, so nothing was
lost in generation — the FR24 FM set simply is not modelled upstream.

That rules out "regenerate and it appears" and leaves a genuine choice, which is David's:

1. **The two specials are wrong** — drop `{freq: 33, label: E}` and `{freq: 34, label: F}` from the
   AJS-37's `trailing_specials`. Cheapest, and correct if nobody uses them.
2. **The FR24 is real and missing** — add it as hand-written data. `mod: 1` on both entries says
   the author meant FM, which supports this reading, and it is the *same shape of work* as ticket
   03's FC3 gap: a VEAF overlay for radios DCS has but the datamine does not model.

Option 2 only makes sense together with ticket 03; option 1 stands alone. Either way the current
state — two channels reported dropped on every single build — should not survive.
