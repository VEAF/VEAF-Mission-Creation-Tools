# VDW-001 — audit each vendored artifact's real provenance (by content diff)

Status: ✅ done
Type: chore (investigation)
Files: — (produces the data for VDW-002)

## What to build

For every vendored artifact, establish its **real** source and divergence by **comparing
content** — never by assuming a VEAF fork is the source (a fork is often only a
contribution fork).

Artifacts to cover: `mist`, `CTLD`, `CSAR`, `AIEN`, `TheUniversalMission` (TUM), `Skynet`,
`Hercules_Cargo`, `DCS-SimpleTextToSpeech`, the Python `luadata` lib, the community sounds
(`CSAR.ogg`, `beacon*.ogg`, `radiobeep.ogg`), and `dcs-world-api-schema.json` (watched only).

For each: diff the vendored file against (a) the plausible upstream and (b) any VEAF fork,
then record:
- `source` (where we actually vendor from) and `upstream` (reference origin),
- `vendoring` mode: `verbatim` | `adapted` | `fork` | `compiled`,
- `pinned` version/commit currently shipped,
- `manual_steps` to update (re-apply patches / rebase fork / recompile), for non-verbatim.

## Acceptance criteria

- [x] Provenance table for all artifacts, each backed by a content comparison (not by fork existence) — captured directly in `vendored.yaml`
- [x] Vendoring mode + source/upstream + pinned version recorded per artifact
- [x] `manual_steps` drafted for every non-`verbatim` artifact

## Blocked by

—
