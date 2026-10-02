# 03 — #953: what Tripack's 09-19 test settles

Status: ✅ done 2026-10-02 — reply drafted for David; the group half stays in `DCS-SESSION-TODO.md` R15

[#953](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/953) had no answer since Tripack's
test of 2026-09-19. On a v6 mission, from a blue slot and as Tactical Commander: neutral statics hidden
in the editor and touched by no script stay hidden; the identical ones a combat zone recreates show on
the map, and vanish and come back with the zone.

## Checked in the code

The zone puts a static back through `VeafGroupSpawn` → `veafDcsSpawner.addStatic`, which submits the
editor record's `hidden`, `hiddenOnMFD` and `hiddenOnPlanner` to `coalition.addStaticObject` —
`test_the_static_the_zone_puts_back_is_still_hidden` pins all three. So the flag is sent and DCS does not
apply it to a static a script created: R15's **Ignored** branch, for statics.

## What was done

- `dcs-scripted-static-ignores-hidden` added to `known-limitations.yaml`, `dcs-runtime-traps.md`
  regenerated.
- R15 records the result and narrows what is left to the group half (a red group recreated by
  `coalition.addGroup` — the QRA side of the report).
- A reply for Tripack, for David to post.

Not done, and a decision rather than a fix: whether a zone active at start should keep the editor's
own statics instead of destroying and recreating them, which is the only way to keep them hidden.
