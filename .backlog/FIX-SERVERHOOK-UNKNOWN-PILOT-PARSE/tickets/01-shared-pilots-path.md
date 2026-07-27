# 01 — Default the pilots file to the shared Saved Games root

Status: ✅ done

## Context

`loadPilots` looked for `veaf-pilots.txt` under `VEAF_SERVER_DIR`
(`writedir()\scripts\hooks\`), the per-server Hooks folder. The VEAF servers share a
single `veaf-pilots.txt` in the parent `Saved Games\` root, so the file was never
found and no pilot was ever recognized.

## Change

- Add `VEAF_SHARED_DIR = DCS_DIR .. [[..\]]` (parent of `writedir()`, i.e. the shared
  `Saved Games\` root).
- Default the load path to `(veafServerHook.pilotsDir or VEAF_SHARED_DIR)`.
- Keep `VEAF_SERVER_DIR` (public global, may be referenced by a companion hook).
- Update the `pilotsDir` comment and the FR/EN install docs.

## Done when

- A shared `Saved Games\veaf-pilots.txt` is loaded by every server with no
  per-server config; `pilotsDir` still overrides for a standalone server.
