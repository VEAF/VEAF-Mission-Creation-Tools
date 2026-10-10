# 06 — Stocks: warehouses, ground reserve, SAM missiles

Status: 🧑 waiting-human

David, 2026-10-06: keep munitions, aircraft and ground units, so that the strategic side is real — destroying the enemy's logistics means fewer tanks facing us, making a SAM network fire 90 % of its missiles makes it less aggressive.

## Aircraft and munitions: the airbases' warehouses

- At build, the warehouses of every campaign airbase are written from the campaign state (`warehouses_injector`, already able to set limited stocks per airfield).
- During the flight their content is read (`Airbase:getWarehouse()`, `getInventory()` / `getItemCount()`) and written into the state file (ticket 05). Whether those counts are exact and cover aircraft as well as weapons is **to measure first**.
- A captured airbase's warehouse goes to its new owner as found.

## Ground units: a reserve per side

- Each side has a reserve per category (armour, air defence, transport), at the campaign level.
- Zones of `kind: logistics` feed it between missions (ticket 08); destroying them lowers what the reserve gets.
- A garrison drawn or reinforced takes from the reserve; an empty reserve means a smaller draw.

## SAM missiles

- During the flight, the remaining missiles of every air defence unit are read (`Unit:getAmmo()`) and written to the state.
- Whether a ground unit can **start** a mission with fewer missiles is to measure.
  If it can, the next mission sets it.
  If it cannot, a low stock is rendered as fewer active launchers and a more cautious IADS (Skynet going dark sooner) — which is the "less aggressive" David describes.
  The measurement goes to known limitations either way.

## Done when

Tests cover: warehouse read into the state, warehouse written at build from the state, reserve consumed by a draw and fed by a logistics zone, SAM ammo recorded and its rendering at next start; the two measurements above recorded with their date.
