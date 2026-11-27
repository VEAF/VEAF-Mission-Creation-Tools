# 01 — The state file carries a `sitac` block

Status: ✅ done
Type: feature

## What

`veafCampaign.stateTable()` adds a `sitac` sub-table, rebuilt at each save, made for a reader outside DCS:

- `theatre`, `campaign`, `updated` (simulation time);
- `zones`, a list in the campaign's order: name, waypoint, kind (`airfield`, `outpost`, `factory`, `depot`), lat/lon of the centre (`coord.LOtoLL`), owner, garrison counts (`alive`, `total`), capture in progress (`side`, `seconds`), buildings standing/total for a factory or a depot, awake or asleep;
- `connections`, pairs of zone names;
- `convoys` under way: side, from, to, units alive;
- `sides`: per side, the credits (the players' side) and the resource stock.

## Done when

- The block is written at every save, and the reload ignores it (a save that carries one reloads as before).
- Tests in `test/lua/`; the block documented in `doc/` (FR and EN); CHANGELOG entry; the Lua gate passes.
