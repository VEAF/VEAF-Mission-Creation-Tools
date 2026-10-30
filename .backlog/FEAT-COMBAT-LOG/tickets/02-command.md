# 02 — `veaf-tools mission combat-log`: the recap per pilot

Status: ✅ done — 2026-10-30 (PR #1222)

Reads the file and prints, per player, the weapons fired, the gun rounds, the hits and the kills with their mission-clock time (⚠ on friendly fire); `--ai` adds the AI shooters, `--json` the machine form. Logic in `veaf_libs/combat_log.py`, the command maps arguments.

Done when: tests cover the recap, a line cut short, the clock, both outputs; documented in CLI_REFERENCE, the GUIDE and the module's page (FR and EN).
