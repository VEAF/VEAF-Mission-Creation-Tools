# 02 — `veafDynamicConfig.lua` is embedded and never referenced

Status: 🚫 wontfix — 2026-08-10, established and documented
Type: chore
Files: `src/python/veaf-tools/mission_builder/mission_builder_worker.py`

## What was measured

The editor pruned `l10n/DEFAULT/veafDynamicConfig.lua` alongside the sounds. Unlike them, nothing
breaks: the mission loads it **from disk** at runtime, not from the archive —

```lua
assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veafDynamicConfig.lua"))()
```

— and it is absent from `mapResource`, so the embedded copy is dead weight in every `.miz`.

## The question to settle before touching anything

Either the static-loading path is supposed to use the embedded copy and does not — in which case
this is a **bug** and the file needs a `mapResource` entry and a `a_do_script_file` — or it is
genuinely unused and should not be embedded. Read both load paths before deciding; the file name
appearing in the mission table is not evidence that the *archived* copy is what runs.

## Tasks

- [ ] Establish which of the two, from the code.
- [ ] Apply it: register the resource, or stop embedding the file.
- [ ] Either way, a test asserting the archive and the load path agree.

## Settled: unused, and left where it is

Established from the code, as the ticket asked, rather than from the file name appearing in the
mission table:

- **Dynamic mode** loads it off disk — `loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veafDynamicConfig.lua")`.
- **Static mode** does not load it at all: `_ordered_mission_script_files` excludes it on purpose,
  because it *is* the dynamic loader.

So the archived copy is read by nothing, and the editor pruning it costs nothing. It is **not**
declared alongside the sounds: declaring it would assert a dependency that does not exist.

Not removed from the archive either. The explicit entry in `get_mission_script_files()` is
redundant — the `src/scripts/*.lua` catch-all right below it packages the file anyway — so stopping
it would mean narrowing that glob, which exists precisely to package a mission maker's own scripts.
Risking a silently dropped script to save 780 bytes is a bad trade. The reasoning now sits in a
comment at the list, and a test pins the behaviour, so the next reader does not re-open it.
