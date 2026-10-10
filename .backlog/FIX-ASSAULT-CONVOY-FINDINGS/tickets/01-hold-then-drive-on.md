# 01 — A convoy holding with nobody of its side to order it drives on by itself

Status: ✅ done

- `ConvoyUnitHandler:standDown`, after a fall back: still hold (Q4), but when **no player of the convoy's coalition is connected** (`coalition.getPlayers`), drive on by itself after a delay — 300 s proposed — as after a fight (`resume`), re-checked when the delay ends so a player who connected meanwhile keeps the choice.
- Say in the doc what counts as "a player of that side" (a game master in a neutral slot does not).
- Lua tests: holding with no player of that side → drives on after the delay; with one → keeps holding; a new contact meanwhile → no resume.
- `veafGroundAI.md` / `.en.md`: the hold after a fall back, and when it ends by itself.
