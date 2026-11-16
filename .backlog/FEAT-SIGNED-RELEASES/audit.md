# FEAT-SIGNED-RELEASES — Ticket 01 audit: what the executables bundle, under which license, and what they contact

Audited on 2026-11-13 at `6c4b9b92` (`develop` = `origin/develop`), read-only.
Measured against SignPath Foundation's terms as summarised in [PRD.md](PRD.md): an OSI-approved license with no commercial dual-licensing for all components, no proprietary code (system libraries allowed), and a privacy statement.

## Method

- The build was read, not run: `.github/workflows/release.yml`, `veaf_build/worker.py` (`_veaf_tools_extra_data`, `_build_pyinstaller_executable`, `_LAZY_PACKAGES`, `_DATA_PACKAGES`, `build_veaf_logs`), `src/go/veaf-logs/go.mod`.
- Python licenses were read from the installed distributions' metadata (`License-Expression`, `License`, classifiers, license files) in the project's Poetry environment, walking the dependency closure of `[tool.poetry.dependencies]` with Windows markers.
  The local environment lags `poetry.lock` by a patch level on a few packages (e.g. avwx-engine 1.9.9 installed, 1.9.10 locked); no license changes at patch level were found, but this was not re-read on the locked versions.
- Go licenses were read from the `LICENSE` files in the Go module cache (`%USERPROFILE%\go\pkg\mod`) at the versions pinned in `go.mod`.
- Upstream repository licenses were read from the GitHub API (`gh api repos/<owner>/<repo> --jq .license.spdx_id`).
- Data-file provenance was read from each file's own header comment and from `vendored.yaml`.
- No executable was built, so the exact list of DLLs and modules PyInstaller collected was not produced; see finding F8.

## What each executable is built from

| Executable | Build | Entry point | Content |
|---|---|---|---|
| `veaf-tools.exe` | PyInstaller `--onefile`, `poetry install --with build --all-extras` (no extras are declared, so this is main + dev + build groups; only what is imported is frozen) | `src/python/veaf-tools/veaf-tools.py` | The CPython 3.13 runtime, the imported closure of the main dependencies, the in-tree packages, `--collect-submodules mission_builder`, `--collect-data avwx` and `pptx`, and the `--add-data` list of `_veaf_tools_extra_data` |
| `veaf-tools-updater.exe` | PyInstaller `--onefile` | `src/python/veaf-tools/veaf-tools-updater.py` | The CPython runtime, `veaf_libs`, `veaf_tools.helpers` and the third-party packages they import (a subset of the list below), `--add-data veaf_libs/locales`, `--hidden-import veaf_tools._version` |
| `veaf-logs.exe` | `go build -trimpath -ldflags "-s -w -H windowsgui -X …Version=<v>" ./cmd/veaf-logs` (`veaf-build build-logs`), Go toolchain from `go.mod` (`go 1.27`) | `src/go/veaf-logs/cmd/veaf-logs` | The Go runtime and standard library, the modules of `go.mod`, the embedded `internal/logcore/rules.json`, and `rsrc_windows_amd64.syso` (manifest + icon) |

The Lua scripts (VEAF and community) are **not** inside any executable.
They ship in `published.zip` (`src/scripts/veaf/veaf-scripts.lua`, `src/scripts/community/*`), which the updater downloads; see "Outside the signed executables" below.
The only Lua-derived content inside `veaf-tools.exe` is two JSON lists generated from VEAF's own Lua at build time (`veaf_modules_list.json`, `veaf-shortcuts.json`).

## Inventory and classification

Classes: **OK** = OSI-approved and compatible; **?** = not OSI or unclear; **DCS** = proprietary or derived from DCS World files.

### A. Runtime and toolchain inside the executables

| Component | License | Read from | Class |
|---|---|---|---|
| VEAF code (all in-tree Python packages, `veaf-logs` Go code, `rules.json`, locales, MCP authoring guide and prompts, known-limitations, checklists, convert profiles, `veaf-units.yaml`, `theatre-bounds.yaml`, `mission_builder/data/*.json`, `dcs-radio-layouts.yaml`, `veaf-logs.ico`) | Apache-2.0 | `LICENSE.md`; icon drawn for the project (commit `41a596c6`) | OK |
| CPython 3.13 runtime (`python313.dll`, stdlib) | PSF-2.0 | Python's own license (not re-read in this repo) | OK |
| Libraries the CPython Windows build bundles and PyInstaller collects when imported: OpenSSL (via `ssl`/`requests`), libffi (via `ctypes`), zlib, bz2, liblzma | Apache-2.0, MIT, Zlib, bzip2-1.0.6, 0BSD/public domain | Not read: no exe built (F8) | OK expected, to confirm |
| `vcruntime140.dll` (MSVC runtime collected by PyInstaller) | Microsoft redistributable | Not read | System library, allowed by the terms |
| PyInstaller 6.22.3 bootloader | GPL-2.0-or-later with the bootloader exception (exe may carry any license) | `pyinstaller-6.22.3.dist-info` `License` field, `COPYING.txt` | OK |
| pyinstaller-hooks-contrib 2026.7 (runtime hooks) | Apache-2.0 / GPL-2.0 (dual, per hook) | classifiers, `LICENSE` | OK |
| PyInstaller default icon on `veaf-tools.exe` and `veaf-tools-updater.exe` (no `--icon` passed) | Part of PyInstaller, covered by its exception | `worker.py` passes no `--icon` | OK |
| Go runtime and standard library | BSD-3-Clause | Go's own license (not re-read) | OK |

### B. Third-party Python packages frozen into `veaf-tools.exe` (the updater carries a subset)

All read from the installed `*.dist-info` metadata.

| Package | Version | License | Class |
|---|---|---|---|
| annotated-doc | 0.0.4 | MIT | OK |
| annotated-types | 0.7.0 | MIT | OK |
| anyio | 4.14.2 | MIT | OK |
| astral | 3.2 | Apache-2.0 | OK |
| attrs | 26.1.0 | MIT | OK |
| avwx-engine (+ its station data, `--collect-data avwx`) | 1.9.9 | MIT | OK |
| certifi (CA bundle `cacert.pem`, collected by its hook) | 2026.10.19 | MPL-2.0 | OK |
| charset-normalizer | 3.4.7 | MIT | OK |
| click | 8.3.3 | BSD-3-Clause | OK |
| colorama | 0.4.6 | BSD (classifier) | OK |
| fonttools | 4.67.0 | MIT | OK |
| fpdf2 | 2.8.9 | LGPL-3.0-only | OK (copyleft obligations, see F7) |
| geographiclib | 2.1 | MIT | OK |
| geopy | 2.5.0 | MIT | OK |
| h11 | 0.16.0 | MIT | OK |
| httpcore / httpcore2 | 1.0.9 / 2.12.0 | BSD-3-Clause | OK |
| httpx / httpx2 | 0.28.1 / 2.12.0 | BSD-3-Clause | OK |
| idna | 3.18 | BSD-3-Clause | OK |
| inquirerpy | 0.3.4 | MIT | OK |
| jsonschema, jsonschema-specifications, referencing | 4.26.0, 2025.9.1, 0.37.0 | MIT | OK |
| lxml | 6.1.3 | BSD-3-Clause | OK |
| markdown-it-py, mdurl | 4.2.0, 0.1.2 | MIT | OK |
| mcp, mcp-types | 2.3.0 | MIT | OK |
| opentelemetry-api | 1.45.1 | Apache-2.0 | OK |
| pfzy | 0.3.4 | MIT | OK |
| pillow | 13.0.0 | `MIT-CMU` (License-Expression) | ? — see F6 |
| prompt-toolkit | 3.0.52 | BSD (classifier) | OK |
| pydantic, pydantic-core | 2.14.1, 2.50.1 | MIT | OK |
| pygments | 2.20.0 | BSD-2-Clause | OK |
| pyjwt | 2.15.0 | MIT | OK |
| python-dateutil | 2.9.0.post0 | Apache-2.0 + BSD-3-Clause (dual, both OSI) | OK |
| python-multipart | 0.0.32 | Apache-2.0 | OK |
| python-pptx (+ `templates/default.pptx`, `--collect-data pptx`) | 1.0.2 | MIT | OK |
| pywin32 (required by mcp on Windows) | 312 | PSF (classifier) | OK |
| pyyaml | 6.0.3 | MIT | OK |
| requests | 2.34.2 | Apache-2.0 | OK |
| rich | 14.3.4 | MIT | OK |
| rpds-py | 2026.6.3 | MIT | OK |
| ruamel.yaml | 0.19.1 | MIT | OK |
| shellingham | 1.5.4 | ISC | OK |
| six | 1.17.0 | MIT | OK |
| sse-starlette, starlette, uvicorn | 3.4.5, 1.3.1, 0.51.0 | BSD-3-Clause | OK |
| truststore | 0.10.4 | MIT | OK |
| typer | 0.27.3 | MIT | OK |
| typing-extensions | 4.16.0 | PSF-2.0 | OK |
| typing-inspection | 0.4.4 | MIT | OK |
| tzdata | 2026.2 | Apache-2.0 | OK |
| urllib3 | 2.8.0 | MIT | OK |
| wcwidth | 0.7.0 | MIT | OK |
| xlsxwriter | 3.2.9 | BSD-2-Clause | OK |
| xmltodict | 1.0.4 | MIT | OK |
| `luadata` (vendored in-tree, `src/python/veaf-tools/luadata`, adapted from leafvmaple/luadata 1.0.5) | BSD-3-Clause | GitHub API on `leafvmaple/luadata`; `vendored.yaml`; **no license file in the vendored copy** | OK (notice missing, F7) |

None of these is dual-licensed with a commercial option.
`cryptography`/`cffi` (pyjwt's optional `crypto` extra) and `httpx2-jsfetch` did not resolve under Windows markers and were not counted.

### C. Data files added with `--add-data` to `veaf-tools.exe`

| File(s) | Provenance (from the file header unless stated) | License | Class |
|---|---|---|---|
| `veaf_libs/data/dcsUnits.yaml` (254 kB) | "Generated from Quaggles/dcs-lua-datamine", itself a dump of DCS World's in-memory Lua tables | datamine repo has **no license** (GitHub API: none); the content is Eagle Dynamics' game data | **DCS** |
| `veaf_libs/data/dcs-countries.yaml` | Same datamine | none | **DCS** (a name→id table) |
| `presets_injector/data/dcs-radio-specs.yaml` | Same datamine | none | **DCS** |
| `veaf_libs/data/payloads.yaml` (612 kB) | "Read from a DCS World install, `MissionEditor/data/scripts/UnitPayloads/*.lua` and `CoreMods/**/UnitPayloads/*.lua`" | ED's files | **DCS** |
| `veaf_libs/data/payloads-ai-bombers.yaml` (1 kB) | Hand-written from `db.Units.lua` of the DCS install | VEAF, from ED data | **DCS** (small) |
| `veaf_libs/data/cockpit-controls/*.yaml` (6 aircraft, 604 kB) | "Generated from `<module>/Cockpit/Scripts/clickabledata.lua` in a DCS install" | ED's and module makers' files | **DCS** |
| `veaf_libs/data/airfield-frequencies.yaml` | "Captured from a running DCS with the Mission Editor's own logic", TACAN from `Beacons.lua` | ED's data | **DCS** |
| `veaf_libs/data/airdromes.yaml`, `airdrome-positions.yaml` | YoloWingPixie/dcs-world-schema reference data, plus VEAF's runtime airbase dumps | dcs-world-schema is MIT (GitHub API), but what it packages is DCS data | **DCS** (MIT label does not change the origin) |
| `veaf_libs/data/parking/*.json` (11 theatres, 2.3 MB) | VEAF runtime captures of `Airbase:getParking()` | VEAF-produced measurement of DCS | **DCS** (measured, not copied from files) |
| `veaf_libs/data/clear-ground/*.json` | VEAF probe sweeps of DCS terrain (`veaf-tools dcs …`) | VEAF-produced measurement | ? — VEAF output, low risk |
| `veaf_libs/data/wmm/WMM1985–2025.COF` | `magnetic.py`: NOAA World Magnetic Model coefficients, "copied from DCS's" `Data/MagVar/COF` | NOAA, public domain (stated in `magnetic.py`, not re-read at NOAA) | ? — public-domain content, copied from the DCS install |
| `veaf_libs/data/dcs-maps.yaml` | Export of VEAF/dcs-maps (ADR 0015) | MIT (GitHub API, ADR 0015) | OK |
| `veaf_libs/data/theatre-defaults.yaml` | Extracted from the calibration missions of VEAF/dcs-maps | MIT | OK |
| `veaf_libs/data/fonts/DejaVuSans*.ttf` | DejaVu fonts, `DejaVu-LICENSE.txt` shipped beside them | Bitstream Vera license + public domain changes | ? — free but not an OSI license (F5) |
| VEAF-authored files listed in section A | — | Apache-2.0 | OK |

The `veaf_libs/data/dcs-schema/` directory (dcs-world-schema API definitions) is in the source tree but is **not** in the `--add-data` list, so it is not bundled.

### D. `veaf-logs.exe` Go modules

| Module | Version | License (first lines of `LICENSE` in the module cache) | Class |
|---|---|---|---|
| github.com/pkg/sftp | v1.13.12 | BSD-2-Clause | OK |
| github.com/tailscale/walk | v0.0.0-20260702185836 | BSD-3-Clause ("The Walk Authors") | OK |
| github.com/tailscale/win | v0.0.0-20260619195133 | BSD-3-Clause ("The win Authors") | OK |
| github.com/dblohm7/wingoes | v0.0.0-20231019175336 | BSD-3-Clause | OK |
| golang.org/x/crypto | v0.58.0 | BSD-3-Clause | OK |
| golang.org/x/sys | v0.49.0 | BSD-3-Clause | OK |
| golang.org/x/exp | v0.0.0-20250408133849 | BSD-3-Clause | OK |
| github.com/kr/fs | v0.1.0 | BSD-3-Clause | OK |
| gopkg.in/yaml.v3 | v3.0.1 | MIT and Apache-2.0 | OK |
| gopkg.in/Knetic/govaluate.v3 | v3.0.0 | MIT | OK |
| `akavel/rsrc` | v0.10.2 | build-time generator only (`go:generate`), not linked | — |

`veaf-logs.exe` is clean.

### Outside the signed executables (context, not in scope of the signature)

These are not inside any `.exe`, but a reviewer reading "all components" of the project may look at them.

| Component | Where it ships | License | Note |
|---|---|---|---|
| VEAF Lua framework (`src/scripts/veaf/*`) | `published.zip` | Apache-2.0 | `veaf-scripts.lua` also carries `dcsUnits.lua`, rendered from `dcsUnits.yaml` (DCS-derived) |
| MIST (`mist.lua`) | `published.zip` | GPL-3.0 (mrSkortch/MissionScriptingTools, VEAF fork) | OSI |
| AIEN | `published.zip` | GPL-3.0 (Chromium18/AIEN, VEAF fork) | OSI |
| The Universal Mission | `published.zip` | GPL-3.0 (akaAgar) | OSI |
| Skynet-IADS (compiled) | `published.zip` | Apache-2.0 (VEAF/Skynet-IADS) | OSI |
| DCS-SimpleTextToSpeech | `published.zip` | MIT (ciribob) | OSI |
| CTLD | `published.zip` | header says "Licence : MIT"; neither ciribob/DCS-CTLD nor VEAF/CTLD has a license file (GitHub API: none) | unclear |
| CSAR | `published.zip` | **none** found (ciribob/DCS-CSAR and VEAF/DCS-CSAR: none; no header) | unclear |
| `src/scripts/community/sounds/*.ogg` | `published.zip` | provenance not recorded | unclear |
| `dcs-serve.exe` (VEAF/VEAF-dcs-bridge) | map capture kit zip | **VEAF-dcs-bridge has no license** (GitHub API: none) | would block signing `dcs-serve.exe` |
| `vendored.yaml` lists `Hercules_Cargo.lua` (Anubis mod, no license) | not present in `src/scripts/community/` at this commit | — | stale entry |

## Network behaviour (for the privacy statement)

Nothing listens on a public port: the MCP server runs on stdio (`mcp.run()`), and the DCS bridge calls go to `127.0.0.1`.

| Executable | Contacts | When | Triggered by the user? | Sends |
|---|---|---|---|---|
| `veaf-tools.exe` | `api.github.com` (`releases/tags/published-latest`) | At every CLI start, at most once a day (cached in VEAF home), only when stdout is a terminal (`veaf_libs/update_checker.py`, called from `veaf_tools/app.py`) | **No — automatic, on by default**; opt-out `check_updates: false` in the user config | Version in the User-Agent |
| `veaf-tools.exe` (MCP server) | `api.github.com`, then starts the updater in the background, which downloads the release assets | At server start, at most every 4 hours (`veaf_mission_mcp/self_update.py`); skipped when `VEAF_MCP_UPDATER_TAG` pins a tag | **No — automatic** once the user has configured the MCP server | Version in the User-Agent |
| `veaf-tools.exe` | `github.com/VEAF/VEAF-Mission-Creation-Tools/releases/download/terrain-data/` | First placement on a theatre that has no local elevation grid (`veaf_libs/terrain_data.py`) | Indirectly (a placement command) | Nothing beyond the HTTP request |
| `veaf-tools.exe` | `raw.githubusercontent.com/VEAF/VEAF-dcs-bridge/refs/heads/develop/src/lua/dcs-bridge.lua` | Mission build or map capture needing the bridge script when none is local (`mission_builder_worker.py`, `dcs_bridge_capture.py`) | Yes | Nothing; the script fetched is code from a moving branch, injected into the mission (F9) |
| `veaf-tools.exe` | `aviationweather.gov` by default, or a national service chosen by avwx per country (BOM, KMA, AMO India, etc.) | Building a mission whose weather is set to live METAR | Yes (mission configuration) | The airport ICAO code |
| `veaf-tools.exe` | `nominatim.openstreetmap.org`; `maps.googleapis.com` only when `GOOGLE_MAPS_API_KEY` is set | The MCP `geocode` action | Yes (an agent acting for the user) | The place name searched |
| `veaf-tools.exe` | `tile.openstreetmap.org`, `tile.opentopomap.org` | Rendering a campaign/briefing map | Yes | Tile coordinates |
| `veaf-tools.exe` | `veaf-docs-chatbot.veaf.workers.dev/chat` (VEAF's Cloudflare Worker) | `veaf-tools ask` | Yes | The question and the language |
| `veaf-tools.exe` | `veaf-docs-chatbot.veaf.workers.dev/analyze` | Online analysis of a DCS log excerpt (`veaf_logs/analysis.py`) | Yes | A bounded, redacted log excerpt (`veaf_libs/redaction.py`) |
| `veaf-tools.exe` (MCP `scaffold_mission`) | GitHub release download URL | Scaffolding a mission folder | Yes | Nothing beyond the request |
| `veaf-tools-updater.exe` | `api.github.com` + release asset downloads | When the user runs it | Yes | A GitHub token in `Authorization` only if one is set in the environment |
| `veaf-logs.exe` | `veaf-docs-chatbot.veaf.workers.dev/analyze` | When the user asks to explain an excerpt online | Yes | A bounded, redacted log excerpt |
| `veaf-logs.exe` | SSH/SFTP hosts and DCSServerBot RestAPI URLs | Only the servers the user configures in a profile | Yes | Credentials/API key the user provided, to that server only |

The two automatic update checks mean the statement "sends nothing unless the user asks" is **not** true as shipped; see F3.

## Findings and blockers

### F1 — Blocker: DCS-derived data inside `veaf-tools.exe`

`dcsUnits.yaml`, `dcs-countries.yaml`, `dcs-radio-specs.yaml`, `payloads.yaml`, `payloads-ai-bombers.yaml`, `cockpit-controls/*.yaml`, `airfield-frequencies.yaml`, `airdromes.yaml`, `airdrome-positions.yaml` and `parking/*.json` are extracted from Eagle Dynamics' files or runtime, about 4 MB of the bundle.
They are data, not code, and mostly facts (type names, ids, CLSIDs, frequencies, coordinates), so they may not be protected and may not count as "proprietary code".
But no license covers them, and their source (the Quaggles datamine) itself has none; whether SignPath reads them as a proprietary component is their call, and acceptance has no appeal.

Options, cheapest first:

- **a. Disclose and ask SignPath before applying** (cost: one email; risk: a "no" before we invest anything). Describe the files as factual reference tables extracted from the game the tool targets, under no license, and ask whether they block. Recommended first step: it settles the question for free.
- **b. Move them out of the signed exe into a downloaded file**, like the terrain grids already are (`terrain_data.py`: GitHub release `terrain-data`, manifest + SHA-256, downloaded on first use). Cost: medium — a "reference data" release asset, a loader for the readers of these files (34 Python files under `src/python/veaf-tools` name one of them, a loose upper bound), offline behaviour on first use, tests; every feature that reads them then needs one network access the first time, which must be added to the privacy statement. The data still ships from the project's release page, so this only helps if SignPath judges the signed binary alone.
- **c. Remove them**: not realistic — the MCP oracle, payloads, radio presets, warehouses and placement all read them.
- **d. Give up SignPath for a paid OV code-signing certificate in VEAF's name** (cost: roughly €200–400 a year plus a hardware token or cloud HSM, and an association identity check; no license condition at all). Estimate, not sourced.

### F2 — Blocker candidate: the WMM coefficient files are copied from the DCS install

The content is NOAA's public-domain World Magnetic Model, but `magnetic.py` says the files were copied from DCS's `Data/MagVar/COF`.
Recommendation: re-source the nine `.COF` files from NOAA NCEI's own publications (current and historical epochs) and record that source in the header. Cost: small; the 1990 file already differs from DCS's by one typo fix, which the NOAA original should match.

### F3 — Privacy statement: two automatic network calls

The CLI update check (on by default, daily) and the MCP server's self-update (every 4 hours, downloads and runs the updater) contact GitHub without a user action.
Recommendation: keep them and write a privacy statement that names them, what they send (the version in a User-Agent) and how to turn them off (`check_updates: false`, `VEAF_MCP_UPDATER_TAG`); SignPath's terms allow either a disclosed policy or "sends nothing unless asked". Cost: one documentation page, in ticket 03. Alternative: make both opt-in, which costs the AI zero-setup flow its automatic updates.

### F4 — Product metadata on `veaf-logs.exe`

`veaf-tools.exe` and the updater carry a version resource (`ProductName` "VEAF Mission Creation Tools", `ProductVersion` = release version, `_write_exe_version_file`).
`veaf-logs.exe` carries only a manifest (`assemblyIdentity version="1.0.0.0"`) and an icon: no `ProductName`, no `ProductVersion`.
SignPath asks for the project's name and a consistent version in the product metadata. Recommendation: generate a VERSIONINFO resource at build with the release version (`go-winres` or `rsrc` with a version file, or `goversioninfo`) in ticket 03. Cost: small.

### F5 — Unclear: DejaVu Sans font under the Bitstream Vera license

The Bitstream Vera license is a free font license but is not on the OSI list.
Recommendation: ask SignPath together with F1, or replace the font with one under SIL OFL-1.1, which is OSI-approved (e.g. Noto Sans or Liberation Sans). Cost: small — one font file pair, and a visual check of the briefing PDF.

### F6 — Unclear: Pillow's `MIT-CMU` tag

Pillow 13 declares `License-Expression: MIT-CMU`; it was long declared as HPND, which is OSI-approved.
Whether OSI lists the `MIT-CMU` SPDX identifier itself was not verified here. Recommendation: check the OSI list; if it is absent, cite Pillow's history as HPND to SignPath. Cost: none to low; replacing Pillow is not realistic.

### F7 — Compliance gap, not a SignPath condition: third-party notices are not shipped

PyInstaller `--onefile` does not bundle the `*.dist-info` license files, and the vendored `luadata` has no license file in-tree.
MIT, BSD, Apache-2.0 and MPL-2.0 all require their notice in a binary redistribution, and LGPL-3.0 (fpdf2) requires the notice plus the means to obtain the library's source.
Recommendation: generate a `THIRD-PARTY-LICENSES.txt` at build (e.g. `pip-licenses --with-license-file` on the frozen set, plus the Go modules) and ship it beside the executables and in `published.zip`; add leafvmaple's BSD notice to `src/python/veaf-tools/luadata/`. Cost: small. A SignPath reviewer checking license compliance would likely notice its absence.

### F8 — Not verified: the exact runtime DLLs

Without a build, the list of DLLs PyInstaller collected (OpenSSL, libffi, zlib, liblzma, MSVC runtime) was not read from the artefact.
Recommendation: in ticket 03, list them from the PyInstaller `build/veaf-tools/xref-veaf-tools.html` or the `Analysis` TOC of a CI build, and attach that list to the application. All are expected OSI-licensed or system libraries.

### F9 — Worth knowing: code fetched from a moving branch

`dcs-bridge.lua` is downloaded from `VEAF/VEAF-dcs-bridge`'s `develop` branch HEAD, unpinned, and injected into the user's mission; that repository has no license file.
The signed binary does not execute it (DCS does), so it is not a component of the executable, but SignPath's "no hacking tools / PUP" reviewers may ask what the binary downloads.
Recommendation: add a license (Apache-2.0, like the rest of VEAF) to VEAF-dcs-bridge — which is also required before `dcs-serve.exe` could ever be signed — and fetch a pinned release asset rather than a branch HEAD. Cost: small.

### F10 — Housekeeping found in passing

- CTLD's header says MIT but no upstream file confirms it, and CSAR and the `.ogg` sounds have no recorded license; this concerns `published.zip`, not the signed executables.
- `vendored.yaml` still lists `Hercules_Cargo.lua`, which is not in `src/scripts/community/` at this commit.

## Verdict

**Not as is.** Every code component of the three executables is under an OSI license with no commercial dual-licensing, and `veaf-logs.exe` and `veaf-tools-updater.exe` are clean on their own.
The obstacle is `veaf-tools.exe`'s bundled DCS-derived data (F1), which no license covers; it is data rather than code, so it may pass, but only SignPath can say.

Recommended order:

1. Fix the cheap items whatever happens: re-source WMM from NOAA (F2), ship third-party notices and the luadata notice (F7), license VEAF-dcs-bridge (F9), add a version resource to `veaf-logs.exe` (F4).
2. Ask SignPath Foundation, before applying, whether factual tables extracted from DCS World (F1) and the DejaVu font (F5) are acceptable, disclosing them plainly.
3. If they say yes: apply (ticket 02) with the privacy statement of F3.
   If they say no: either move the DCS-derived tables into a downloaded data release (F1 option b, medium cost) and apply, or sign with a paid certificate in VEAF's name (F1 option d), which has no license condition.
