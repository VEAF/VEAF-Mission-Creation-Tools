# FIX-EXTRACT-GENERATED-ARTIFACTS — the build's own output coming back as a source

Status: ✅ done

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
| 01 | [Extraction stops handing back the build's injected Lua](tickets/01-extract-strips-injected-lua.md) | fix |
| 02 | [The build refuses to embed a leftover artifact](tickets/02-build-skips-leftover-artifact.md) | fix |

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
