# 14 — `inspect_built_mission` shows the date and the briefing pictures

Status: ✅ done

Martinho's session: the AI could not confirm the mission's **date** from `inspect_built_mission` (time only) and opened the `.miz` with a shell to see whether the briefing pictures were in (`l10n/DEFAULT/*.jpg`, `mapResource`) — against the guide's "never read a mission through a shell".

Fix: `inspect_built_mission` reports the date with the time, and the briefing pictures (the `mapResource` keys and whether each file is in the archive and listed for the players' side).

Done when: a test builds a mission with a briefing and finds the date and the pictures in the inspection; one without pictures says none.

## Result

Fix: `inspect_built_mission` puts the date before the time on each weather line (`main: 2015-10-13 06:15, …`) and gains `briefing_pictures`: each resource, its file, whether the archive holds it, and the sides it is listed for (`absent` without any). Test: before and after `build_mission_briefing`.
