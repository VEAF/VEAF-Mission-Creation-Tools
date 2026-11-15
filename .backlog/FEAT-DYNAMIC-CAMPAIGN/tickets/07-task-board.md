# 07 — A task board drawn from the situation

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

Analysis note 05 §11, kept to 3 or 4 tasks.

- `tasks.count` (3) tasks at once for the players' side, drawn again every `tasks.refresh_seconds` (300 s) for the empty slots:
  - **Attack** an enemy zone connected to ours: done when it is no longer the enemy's;
  - **Capture** a neutral zone: done when it is ours;
  - **Resupply** one of our damaged zones: done when its strength is back to 100 %;
  - **Air superiority**: shoot down `tasks.air_kills` (2) enemy aircraft while it is posted.
- Each has a map mark for the side, a reward (`tasks.rewards`), and is listed under Campaign → Tasks.
- A task whose target changed hands the other way is withdrawn, without reward.
- Posting, completion and withdrawal are told to the side.
- The campaign's `briefing.yaml` text, when there is one, goes into the mission briefing as today; the doc says what to put there for a persistent mission.

## Done when

Lua tests: drawing from a situation, no duplicate target, completion and reward, withdrawal, marks removed.
In game: the menu lists three tasks with their marks.
