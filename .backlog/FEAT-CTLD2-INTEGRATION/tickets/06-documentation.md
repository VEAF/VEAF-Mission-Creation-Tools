# 06 — documentation: the new CTLD mode of operation

**Status:** ✅ done

Can proceed alongside 02→04; finish it once 05 has settled the runtime behaviour.

## What changes

The mission maker's mental model changes on three points, and all three are currently documented the
old way:

1. **Configuration lives in `ctld-config.yaml`, edited with `ctld-tools.exe`** — not in
   `mission.yaml`. Say plainly that the tool opens in a browser on a double-click, that the build
   injects the file, and that its own "inject into .miz" button must **not** be used on a VMCT
   mission (the next build would overwrite it).
2. **Zones are named by prefix** — `LGZ_` (logistic), `TRZ_` (troops), `WPZ_`, `EXZ_`, `AIZ_` —
   discovered at boot. The reserved names `logistic #001..020` and `pickzone #001..020` are gone.
   Note the shift for anyone migrating: `logistic #001` designated a **unit or static** and the zone
   followed the object; `LGZ_` is an **editor zone**, and following a moving object now means
   attaching the zone to a unit in the ME (Moving Zone).
3. **What VEAF sets for you** — the values from the VEAF patch (ticket 02), and the fact that they
   are the *starting point* of a mission's config, not a floor: editing `ctld-config.yaml` can undo
   them.

Pages to touch: the CTLD sections of `doc/mission-maker/GUIDE.md`, `doc/MISSION_YAML_REFERENCE.md`
(the `CTLD:` entry loses `settings:`), `doc/TOOLS_REFERENCE.md`, `doc/LUA_API_REFERENCE.md` (the
`veaf.ctld_*` functions are gone), and the migration guide. Each in **FR and EN**, with explicit
English anchors on any section linked from elsewhere.

## Acceptance

- `poetry run docs-check` green.
- No page still shows `CTLD: { settings: … }` or the reserved zone names.
- A reader who has never used CTLD 2 can go from a blank mission folder to a configured mission
  without reading the CTLD repo's own documentation — link to it, don't duplicate it.

## Out of scope

CTLD's own documentation (gameplay, crates, JTAC…) lives at veaf.github.io/CTLD and stays there.
VMCT documents the *integration*, not the script.
