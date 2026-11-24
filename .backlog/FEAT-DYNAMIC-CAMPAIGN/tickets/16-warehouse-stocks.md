# 16 — Weapon stocks per warehouse, moved by players

Status: ✅ done

PRD row "Weapon stocks per warehouse, moved by players"; analysis note 07 §9, §17.

## What

- **The stocks survive a restart**: each airfield zone's weapon counts, read from its DCS warehouse at every save (V1 already records them), are set back at the next load. A count DCS reports as unlimited is left alone.
- **Players move stock**: in a helicopter or a transport aircraft, on the ground at an airfield zone of their side, Campaign → Warehouse → *Load weapons* takes `warehouse.load` (10) of each weapon the warehouse holds (fewer when it has fewer) into the aircraft; *Unload weapons*, on the ground at another airfield zone of the side, puts exactly that into its warehouse; *Cargo* tells what is aboard.
- The cargo is lost with the aircraft, and with the server: it is not saved.
- An unload at another zone pays `economy.warehouse_delivery` (50) credits, once per airfield in each life of the aircraft: weapons carried back and forth earn nothing more.
- Off with `warehouse.enabled: false`.

## Decided here, not in the PRD

- The campaign does not set any warehouse to limited or unlimited: that stays the Mission Editor's (or the airfield's) choice. A warehouse left unlimited simply has nothing to move.
- A lost airfield's stocks are not emptied: Foothold empties them, but whether `setItem(…, 0)` on an unlimited warehouse makes it finite is not measured; to decide after the in-game check.

## Done when

Lua tests: counts restored at load, an unlimited count skipped; load takes at most N of each and only from a friendly airfield, on the ground, in a transport; unload exact, only at another friendly airfield; credits; cargo lost when the aircraft dies.
