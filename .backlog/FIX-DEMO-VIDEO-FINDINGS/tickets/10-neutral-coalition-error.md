# 10 — `add_group` and the coalition `neutral`

Status: ✅ done

Martinho's session: `add_group` for the village's houses with the coalition `neutral` answered `KeyError: "Unknown coalition: 'neutral'"` — no list of the valid ones, a raw exception name. The AI put the houses on red.

Measure first: which of `add_group`'s coalitions the mission table can hold (DCS has `neutrals` as a coalition for countries, statics included); if a neutral static is faithful to what the Mission Editor writes, accept it; otherwise refuse with the valid values.

Done when: a test either places a neutral static or gets a refusal that names `blue` and `red`; the result of the measurement is written here.

## Result

Measured: a DCS mission table holds `coalition.neutrals` (Martinho's `src/mission/mission` has it), so a neutral static is faithful. `add_group` read `neutral` literally. Fix: `neutral` is read as `neutrals`, and an unknown coalition names what the mission holds. Tests in `test_group_insertion.py`.
