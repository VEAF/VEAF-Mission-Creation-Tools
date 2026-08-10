# 02 — `veafDynamicConfig.lua` is embedded and never referenced

Status: ⬜ ready
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
