# 02 — AJS-37: the E and F specials never reach the mission

Status: 🧑 waiting-human — one experiment decides it, and only David can run it
Type: fix

## The single symptom

ADR 0012 gives the AJS-37 seven specials at absolute slots 41–47. **Two of them are removed
before the mission is written**, on every build:

```
specs AJS37 : one radio, 103.0 – 400.0 MHz          (dcs-radio-specs.yaml)
layout      : slot 44 = 33 MHz FM (E), slot 45 = 34 MHz FM (F)
injector    : _drop_out_of_range_channels() strips both
```

Verified against the shipped data — `validate_frequencies("AJS37", [33.0, 34.0, 127.5, 243.0,
305.0])` returns `[33.0, 34.0]` today.

This is **not** a design question. ADR 0012 decided those seven specials, the packer honours the
decision (`test_radio_preset_ajs37.py:184` asserts E keeps slot 44), and a layer below silently
undoes part of it. The design is not being reopened; it is not being **delivered**.

## Why nobody caught it

| Date | |
|------|--|
| 2026-06-08 (#376) | radio specs and frequency validation arrive |
| 2026-06-13 (#468) | `_drop_out_of_range_channels` arrives, from the v6.4.x manual test campaign |
| 2026-07-09 (#569) | the AJS-37 layout with E/F arrives — **a month later** |

Tripack tested Viggen missions carrying these frequencies and they worked. That is true and it is
not a contradiction: those missions came from the v5-era `radioSettings.lua`, built when **nothing
validated**. The layout entries were written afterwards, against a checker that already existed,
and the two were never put side by side.

## The distinction that resolves it

#468's own message says what the drop is for:

> drop out-of-range radio channels **so the ME can save** […] the DCS Mission Editor refused to
> save ('Invalid frequency 243 MHz')

observed on a P-51D and an SA342. So:

- DCS rejects an out-of-range frequency **when the Mission Editor saves**.
- veaf-tools writes the `.miz` directly and never goes through that path.

Both facts hold at once: a mission built with 33 MHz on an AJS-37 **flies** — which is what Tripack
tested — while DCS would refuse to **re-save** it if anyone opened it in the editor. The guard
therefore buys re-editability, not playability, and pays for it by deleting channels that work in
the air.

Whether that trade is right for the AJS-37 is the open question, and nothing measurable in this
repository answers it.

## The experiment

Build a mission carrying AJS-37 presets, **open it in the Mission Editor, and try to save**.

- **It saves** → the 103–400 spec is incomplete, the FM set is real, and the fix is data: E and F
  come back and the checker stops eating valid channels. Same shape of work as ticket 03.
- **It refuses** → the trade is genuine. Then say so in the layout instead of dropping two channels
  in silence on every build — the current state is the one outcome that is wrong either way.

## Tasks

- [ ] Run the experiment above and record the result here.
- [ ] Apply the corresponding fix.
- [ ] Rebuild and confirm channels 44/45 leave the report.
- [ ] Keep the priority-driven specials (`Sp1`/`Sp2`/`Sp3`/`H`) working — they are why `priority`
      exists on a channel (ADR 0012).
- [ ] CHANGELOG.

## Explicitly not on the table

**Deleting `{freq: 33, label: E}` and `{freq: 34, label: F}` from the layout.** An earlier draft of
this ticket offered that as one of "two possible truths". It is not a truth, it is a reversal:
those values come from Tripack's own `radioSettings.lua`, ADR 0012 adopted them deliberately as
airframe constants, and the work was done and shipped in #569. A ticket about a channel not
arriving must not end with the channel being removed.
