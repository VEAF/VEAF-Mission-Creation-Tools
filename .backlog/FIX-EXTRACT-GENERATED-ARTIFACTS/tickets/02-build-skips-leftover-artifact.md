# 02 — The build refuses to embed a leftover artifact

Status: ✅ done

Type: fix · Files: `mission_builder/mission_builder_worker.py`,
`veaf_libs/locales/{fr,en}.json`, `test/python/mission_builder/`

## The defect

Ticket 01 stops new contamination; it does not clean the folders that already carry the
file. In those, the build still does two wrong things:

1. it embeds the stale copy, because the `src/scripts/*.lua` glob takes everything;
2. it tells the mission maker to declare it under `custom_scripts:`, which would make the
   staleness permanent.

## The fix

A generated artifact found in `src/scripts/` gets its own message — this is build output,
delete it, and here is where the real content is edited (`src/spawn-groups.yaml` for the
spawn database) — and is dropped from the collected script files so the build embeds only
the copy the pipeline injects.

Dropping it is safe for both names: the spawn data is re-injected by the `spawn_data`
pipeline step, and `dcs-bridge.lua` is read from the path given on the command line, never
from `src/scripts/`.

A declaration under `custom_scripts:` does **not** rescue it. Deliberate: the point is that
this file must not be loaded from the mission folder, and honouring the declaration would
reinstate exactly the bug while looking like consent.

**Two doors, not one.** `src/scripts/*.lua` is the one that warns; `src/mission/**` takes
everything too, and the `src/scripts/` check cannot see a copy sitting there — so that one
would be embedded in complete silence. Both collections are filtered by the same helper. The
second door is not how Tripack's file got there (extraction *moves* the file out of
`l10n/DEFAULT`, so nothing is left for the `src/mission/` copy), which is exactly why it is
worth closing: nothing would report it.

## Definition of done

- [x] `src/scripts/veaf-spawn-data.lua` in the mission folder → build warns with the dedicated
      message, not `builder.unexpected_lua_file`
- [x] …and it is dropped from the files that build the `.miz`, so the mission carries only the
      injected copy — asserted on `get_collected_mission_script_files`, which is the single
      input `create_mission` unions into `create_miz`
- [x] Same for `dcs-bridge.lua`
- [x] A copy under `src/mission/` is dropped too, and the rest of `src/mission/` still collected
- [x] Declaring it under `custom_scripts:` changes neither: still warned, still not embedded
- [x] A genuinely unexpected `.lua` (a v5 residue like `veafSecurity.lua`) keeps the existing
      warning **and** is still embedded
- [x] Both locales carry the new keys
