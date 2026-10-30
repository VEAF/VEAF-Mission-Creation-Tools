# veafCombatLog — Combat log for the debrief

**Module ID:** `COMBATLOG` | **File:** `veafCombatLog.lua`

---

## Purpose

Writes every shot, hit and kill of the mission to a file, one JSON line per event, for a debrief that knows who fired what at whom.
A Tacview recording does not say it: it names no shooter, records no destruction, and does not show the helicopters' gun (evening of 2026-10-29 on *Marteau du Golan*).

---

## Activation

In `mission.yaml`, on by default in the shipped mission folder:

```yaml
modules:
  COMBATLOG: true
```

The file is written only when DCS's scripting environment keeps `io`, `os` and `lfs`, as VEAF servers do.
Otherwise the module says so once in `dcs.log` and writes nothing: the mission runs as usual.

---

## The file

`veaf-combat-log-<date>-<time>.jsonl`, in `VEAF_EXPORT_DIR` when it is set, else in the DCS write folder (`Saved Games\DCS…`).
One file per mission start, never deleted by the tools: on a server that restarts often, clean up from time to time.
The file is flushed to disk every 10 seconds (a crash loses at most those 10 seconds), not at every line: a gun run raises one event per shell.

| `event` | DCS event | What the line gives |
|---|---|---|
| `start` | start | theatre, date, start time, real time |
| `shot` | `S_EVENT_SHOT` | shooter, weapon, the target aimed at (guided weapon) |
| `hit` | `S_EVENT_HIT` | shooter, weapon, the target hit |
| `kill` | `S_EVENT_KILL` | shooter, weapon, the target destroyed |
| `shooting_start` / `shooting_end` | gun burst | shooter, gun; at the end, `rounds`, the rounds fired |

The shooter and the target carry their unit name, type, coalition, group and player name.
`t` is the mission time in seconds.
`weapon_object` and `weapon_name` say what DCS handed over: a gun's shell sometimes comes with no weapon object, which the file itself measures.

---

## The recap per pilot

```powershell
.\veaf-tools.exe mission combat-log veaf-combat-log-20261029-211814.jsonl
```

One row per pilot: weapons fired, gun rounds, hits, kills with their time (⚠ on friendly fire).
`--ai` adds the AI shooters, `--json` prints the recap as JSON.
See the [command reference](../../CLI_REFERENCE.en.md#combat-log).

---

## See also

- [mission.yaml reference](../../MISSION_YAML_REFERENCE.en.md) — the modules and their options
