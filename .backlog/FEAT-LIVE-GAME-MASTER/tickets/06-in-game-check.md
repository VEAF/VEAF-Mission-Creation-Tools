# 06 — The in-game check

Status: ⬜ ready

A new entry in `DCS-SESSION-TODO.md` (the next R number), no pilot needed for most of it:

1. With a test mission running and `dcs-serve` started by me, `live_situation` lists the player in the game master slot and the mission's groups.
2. `live_command` `_spawn convoy` from one town to another: the convoy appears and drives (ticket 01's route defect does not come back).
3. `live_command` `_destroy` on a garrison unit of a campaign mission: the state file written next shows the loss (ticket 04).
4. `live_message` to the blue coalition: the text shows for a blue slot, not for a red one.
5. `live_message` with a voice on 251 AM: heard in SRS on a blue slot (ticket 07).
6. The admin journal menu lists the five actions, and `dcs.log` has five `VEAF-LIVE` lines.

The demo mission gets its step (`tour/steps.yaml`) once this passes.
