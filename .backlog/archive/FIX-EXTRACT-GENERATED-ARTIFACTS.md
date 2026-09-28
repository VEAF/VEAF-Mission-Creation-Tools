# FIX-EXTRACT-GENERATED-ARTIFACTS — the build's own output coming back as a source

Status: ✅ done · archived 2026-09-28

Origin: Tripack, 2026-09-03. Building `Snowfox_20260903.miz` printed

> Fichier Lua inattendu `src/scripts/veaf-spawn-data.lua` trouvé dans votre dossier mission.
> Ce fichier sera inclus dans la construction. Vous pouvez le déclarer dans la section
> `custom_scripts` de mission.yaml pour supprimer cet avertissement.

`veaf-spawn-data.lua` is not a script anybody wrote: it is the spawn database
(`veafUnits.UnitsDatabase` / `GroupsDatabase`) rendered from YAML and injected into the
`.miz` at every build (ADR 0005). It has no business in a mission folder, and the advice
the message gives — declare it under `custom_scripts:` — is the one thing that must not be
done with it, since it would freeze a stale copy of the framework spawn database into the
mission.

## The defect

Extraction moves **every** remaining `.lua` of `l10n/DEFAULT` into `src/scripts/`
(`mission_extractor_worker.py:156`). The cleanup that runs first only knows three
families — the VEAF scripts, the legacy v5 ones and the community ones
(`mission_extractor_worker.py:127`). It does not know the files the build injects through a
map resource, because those names live in the injectors, not in `mission_constants`.

Two files are injected that way today:

| File | Map-resource key | Injected by |
|---|---|---|
| `veaf-spawn-data.lua` | `VEAF_MapKey_SpawnData` | `spawn_data_injector_worker.py:33` |
| `dcs-bridge.lua` | `VEAF_MapKey_DcsBridge` | `mission_builder_worker.py:1255` |

So extracting a mission that was built with v6 hands the build's own output back as a
source. On the next build the file is picked up by the `src/scripts/*.lua` glob **and**
re-injected fresh by the pipeline: the `.miz` carries two copies of the spawn database.
The injected one loads from a trigger appended at the highest index, so it should be the
one that wins — but that ordering is an accident of index arithmetic, not a guarantee, and
it does not survive the mission being re-saved in the Mission Editor.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Extraction stops handing back the build's injected Lua](FIX-EXTRACT-GENERATED-ARTIFACTS.md) | fix |
| 02 | [The build refuses to embed a leftover artifact](FIX-EXTRACT-GENERATED-ARTIFACTS.md) | fix |

Ticket 01 stops the contamination; ticket 02 repairs the folders that already carry the
file — Tripack's among them — since re-extracting does not remove a copy already sitting in
`src/scripts/` (`mission_extractor_worker.py:159` keeps it unless `--refresh`).

## Out of scope

- **A copy under `src/mission/`** was *not* left out — it is covered by ticket 02. The
  `src/mission/**` glob embeds everything and the `src/scripts/` check cannot see it, so that
  door would swallow the same duplicate with no message at all. It is not how Tripack's file
  arrived (extraction *moves* the file out of `l10n/DEFAULT`, leaving nothing for the
  `src/mission/` copy), which is exactly the reason to close it: nothing would report it.
- **The generated sounds and images** (`VEAF_MapKey_Sound_*`, `VEAF_MapKey_ActionText_*`,
  `VEAF_MapKey_Assist_*`). They are injected the same way, but they are not `.lua`, so the
  glob at line 156 never moves them into `src/scripts/` and no build re-embeds them from
  there. Nothing observed, nothing changed.
- **Deleting the file from the mission folder for the user.** The build reports and does not
  remove: a mission folder is the mission maker's, and a name we recognise today could be a
  file they wrote tomorrow.

---

## Tickets, in full

## 01 — Extraction stops handing back the build's injected Lua

Status: ✅ done

Type: fix · Files: `mission_tools/mission_constants.py`,
`mission_extractor/mission_extractor_worker.py`, `test/python/mission_extractor/`

### The defect

`MissionExtractorWorker.extract_mission` removes the VEAF, legacy and community scripts by
name, then moves every other `l10n/DEFAULT/*.lua` into `src/scripts/`. A file the build
injected through a `VEAF_MapKey_*` map resource matches neither list, so it is moved — and
becomes a source of the mission it came out of.

### The fix

Drive it from the mission's own `mapResource` rather than from a list of names: every
`VEAF_MapKey_*` entry pointing at a `.lua` file names something this build generated. That
covers the two artifacts of today and any added later without another edit here.

Keep a small set of known names beside it (`GENERATED_LUA_ARTIFACTS`) as the second half of
the union, for the mission whose map resource was rewritten by hand or by a third-party
tool — and because ticket 02 needs those names anyway, where no `mapResource` exists to
consult.

Restricted to `.lua` on purpose: the sounds and images injected under the same prefix are
not moved into `src/scripts/` by the glob, so they are none of this ticket's business.

### Definition of done

- [x] A `.miz` carrying `veaf-spawn-data.lua` + `VEAF_MapKey_SpawnData` extracts to a folder
      with **no** `src/scripts/veaf-spawn-data.lua`
- [x] Same for `dcs-bridge.lua` / `VEAF_MapKey_DcsBridge`
- [x] A `.lua` named by a **non-VEAF** map-resource key is still extracted (we strip our own
      output, not the mission maker's scripts)
- [x] A `.lua` in `l10n/DEFAULT` referenced by no map-resource key at all is still extracted
- [x] An artifact whose map-resource key is missing is stripped anyway, on its name
- [x] The file does not survive in `src/mission/` either — the copy that feeds the next build

---

## 02 — The build refuses to embed a leftover artifact

Status: ✅ done

Type: fix · Files: `mission_builder/mission_builder_worker.py`,
`veaf_libs/locales/{fr,en}.json`, `test/python/mission_builder/`

### The defect

Ticket 01 stops new contamination; it does not clean the folders that already carry the
file. In those, the build still does two wrong things:

1. it embeds the stale copy, because the `src/scripts/*.lua` glob takes everything;
2. it tells the mission maker to declare it under `custom_scripts:`, which would make the
   staleness permanent.

### The fix

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

### Definition of done

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

---
