# 03 — Measure in game what DCS gives

Status: 🧑 waiting-human

Nothing could be measured without DCS running. `DCS-SESSION-TODO.md`, R54, says what to fly and what to read in the file: whether `S_EVENT_HIT` arrives for gun shells and with what, whether `S_EVENT_KILL` names the shooter of a gun kill, whether the burst count matches the rounds fired. What it finds goes into `known-limitations.yaml` (`kind: dcs`), and the recap is adjusted if a field is missing.
