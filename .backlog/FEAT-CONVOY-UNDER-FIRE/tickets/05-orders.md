# 05 — Orders from a human or the game master

Status: ✅ done — `resume` and the merge seen in game 2026-10-08

The convoy's behaviour can be steered with `_gc <convoy>, <verb>`: `retreat` (to the nearest friendly place, or to a named point), `hold`, `resume`.
The same marker commands are what Claude sends through `FEAT-LIVE-GAME-MASTER`'s `live_command`, so the game master needs nothing of its own.
Tests: each verb's parsing and its effect on the handler's state.
