# 01 — *Niveau → 0 avion*: the QRA that scale with the opposition stay on the ground

Status: 🧑 waiting-human — R51 in `DCS-SESSION-TODO.md`
Type: feat

## To do

- Add « 0 avion » at the top of the radio menu *Opposition → Niveau*, and accept `_opposition 0` as a fixed level, like the other values: it stops the follow mode and is announced to everybody.
- A **fixed** level 0 is a switch-off, not a count: a QRA marked `scale_with_opposition: true` does not scramble, whatever enters its zone, until the level is set above 0 or a follow mode is chosen again.
  A level that `follow` lowers to 0 by itself keeps today's behaviour (the zone's own tiers answer), otherwise a quiet minute would silently disable the enemy air.
- A QRA without `scale_with_opposition` is not touched: its zone tiers keep answering.
- The *Niveau actuel* line says it plainly (« aucune chasse adverse (fixe) »).
- Lua tests: fixed 0 → no scramble with intruders in the zone; raised to 2 → the tier of 2; `follow` dropping to 0 → the zone tiers still answer; a QRA without `scale_with_opposition` scrambles at fixed 0.
- Doc `veafQraManager.md` (FR + EN), *opposition level*: the menu entry, the marker value, and the difference between a fixed 0 and a followed 0.

## Decided while implementing

- **The switch-off is a flag set by hand, not "level 0 and no follow mode".** *Mode → fixe* while `air_to_air` sits at 0 freezes a count of 0: reading that as a switch-off would ground the enemy air without anybody choosing it. So only « 0 avion » and `_opposition 0` set it; a level above 0 or a follow mode clears it; *Mode → fixe* keeps it.
- **`level: 0` in `mission.yaml` stays a count**, as before: no mission already built changes behaviour.
- The QRA stays `ready` while switched off and is re-checked on its usual beat, so raising the level sends it at the next check without anything else to do.

## Done when

On a running mission, *Opposition → Niveau → 0 avion* keeps Senaki's QRA on the ground while a player crosses its zone, and *Niveau → 2* sends it again.
