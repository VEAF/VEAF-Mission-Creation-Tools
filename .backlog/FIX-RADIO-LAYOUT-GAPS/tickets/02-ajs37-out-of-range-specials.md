# 02 — AJS-37: the E and F specials never reach the mission

Status: ⬜ ready — the experiment ran on 2026-08-09; DCS accepts the frequencies
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

## The experiment — run 2026-08-09, and it answered

Build a mission carrying AJS-37 presets, **open it in the Mission Editor, and try to save**.

Two subjects were built so an unexpected result could not be blamed on the instrument: a **v6**
mission (format version 23, built the same morning, so no load-time migration) carrying a real
AJS-37 client group copied verbatim from `VEAF-Missile-Training`, and a control identical to it
except those five channels moved into the 103–400 band. Both were opened in the Mission Editor and
saved.

**The editor kept every value, unchanged:**

```
C  before      slots 41-47 : [30, 31, 32, 33, 34, 127.5, 243]
C  after ME    slots 41-47 : [30, 31, 32, 33, 34, 127.5, 243]
```

No refusal, no clamping, no rewrite. The group came back `Client`, in Sweden, intact — so the
editor did process it rather than skip it.

**Conclusion: `dcs-radio-specs.yaml` is wrong about the AJS-37.** `103.0–400.0 MHz` does not
describe what DCS accepts on this airframe, and `_drop_out_of_range_channels` has been deleting
legal channels since July. The fix is data, and there is no trade-off to weigh.

## What to do

- [ ] Correct the AJS-37 entry so 30–34 MHz FM is in range. Say in the file **why** it is
      hand-corrected and that the pinned datamine disagrees, or the next regeneration silently
      reverts it — same hazard as ticket 03.
- [ ] The specs are generated: check whether the generator can carry a hand-written correction at
      all before writing one. If it cannot, that is the first piece of work, not an afterthought.
- [ ] Then verify E and F reach a built mission, in the mission — not in a unit test.

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
