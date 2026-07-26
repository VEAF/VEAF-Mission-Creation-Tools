# 03 — Ship the map-capture kit from the release CI

Status: 🔄 in-progress
Type: feat

## Goal

Stop hand-assembling the kit: every release publishes
`veaf-map-capture-kit-<version>.zip` so David can just hand out a link.

## Decisions (validated with David)

- **No secret in the artifact.** The CI cannot bundle David's `dcs-serve.yaml`. Instead
  `capture-map` **resolves the key itself** from a `dcs-serve.yaml` / `dcs-client.yaml`
  sitting in the working directory or next to the executable (`dcs-serve` writes it on
  first launch). `--api-key` is now optional, `--config` targets a specific file. Net
  effect: the maker command drops to `veaf-tools capture-map --out-dir .` — simpler than
  before, and nothing sensitive is published.
- **Bundle ready bridge missions** (David: "oui, inclus-les") — one per supported theatre,
  generated **without DCS** (`blank_mission` + bridge trigger injection), so a helper
  never has to open the Mission Editor for a known map.
- **`dcs-serve.exe` comes from the other repo's release** (`gh release download --repo
  VEAF/VEAF-dcs-bridge`), best-effort: no release yet → the kit still publishes, without
  the server. Tracked in that repo as `LOT-020` (handoff written).

## Tasks

- [x] `resolve_api_key()` in `veaf_libs/dcs_bridge_capture.py` (explicit → `--config` →
      `dcs-serve.yaml`/`dcs-client.yaml` in cwd then next to the frozen exe), wired into
      `capture-map` and `veaf-build --capture`; i18n keys; 7 tests incl. the actionable
      "start dcs-serve once" message.
- [x] `veaf_build/kit.py`: `build_bridge_mission(s)` (blank mission → `.miz` → inject,
      built in a scratch dir so the injector's timestamped backup never ships),
      `extract_dcs_serve` / `extract_bridge_lua`, `assemble_kit`. 8 tests.
- [x] `veaf-build build-kit` command (prefers the Lua from the bridge zip so missions
      match the shipped server, else downloads it).
- [x] `kit` job in `.github/workflows/release.yml` (needs `release`, Windows runner,
      best-effort bridge download, uploads to the tag **and** mirrors onto
      `published-latest` unless pre-release).
- [x] Procedure updated (download link, no key to copy, `no API key found` troubleshooting)
      FR + EN; CHANGELOG.

## Verified locally

- `build-kit` without a bridge zip → 10 members (exe, PROCEDURE, 9 missions), warns about
  the missing server. With a simulated release zip → 11 members incl. `dcs-serve.exe`
  (54 MB). Bundled missions confirmed to carry `dcs-bridge.lua` + the load trigger and the
  right `theatre` string.
- `capture-map --out-dir .` (no `--api-key`) picks the key up from the kit's
  `dcs-serve.yaml` and fails with a clear message when the server is down.
