# 02 — `setup_cherry` in `ai_clients.py`

Status: ✅ done
A `boot-config.json` with a single entry is followed even if it names an old Cherry executable (David, 2026-11-27: too rare to refuse).
The backup uses SQLite's backup API rather than a copy of the `.sqlite` and `-wal` files: it reads the WAL too and gives one self-contained file.
Type: feature
Files: `src/python/veaf-tools/veaf_libs/ai_clients.py`, `test/python/veaf_libs/test_ai_clients.py` (or the file that covers the other clients), the `ai-setup` command if it lists the clients

Add `setup_cherry(...)` and its entry in `setup_all`, with the guarantees of the other clients: idempotent, existing configuration kept, result `not_found` when Cherry is absent.

## Mechanism (from the study, Cherry Studio 2.2.3, `CherryHQ/cherry-studio` tag `v2.2.3`)

Where: `%APPDATA%\CherryStudio\Data\cherrystudio.sqlite`. If `~\.cherrystudio\boot-config.json` holds `app.user_data_path`, use that folder instead; on any doubt, refuse and print the path found.
`--cherry-data-dir FOLDER` (David, 2026-11-27) overrides both, for a profile Cherry starts with `--user-data-dir`: a forced folder that does not exist is a refusal, not `not_found`, and one without `Data\cherrystudio.sqlite` is refused like the default one.
Tables: `mcp_server` (`id`, `name`, `type`, `command`, `args` and `env` as JSON text, `is_active`, `is_trusted`, `install_source`, timestamps in ms; `id`, `name`, `created_at`, `updated_at` are NOT NULL with no SQL default, drizzle fills them in JS) and `assistant_mcp_server` (`assistant_id`, `mcp_server_id`, timestamps; foreign keys with cascade).

Guards, in this order — refuse without writing when one fails:
1. Cherry runs (`Cherry Studio.exe` process, or `%APPDATA%\CherryStudio\lockfile` locked): "close Cherry Studio, then run again". Why: Cherry's UI replaces the whole set of links of an assistant when it saves, so a write made while it is open can be erased by a stale form.
2. The database is absent (Cherry 1.x or never launched).
3. The two tables do not have the expected columns, or a NOT NULL column without default other than `id`, `name`, `created_at`, `updated_at` was added. Guard by structure, not by version (36 migrations between 2.2.0 and 2.2.3); `version.log` only feeds the message ("tested with 2.2.3").
4. Copy the database and its `-wal` first.
Then write in one `BEGIN IMMEDIATE` transaction, `foreign_keys=ON`, with a timeout.

Write: upsert the server by `name = 'veaf'`.
- It exists: update `command`, `args`, `env`, `updated_at`, and set `type='stdio'`, `is_active=1` (David, 2026-11-27: a server imported through Cherry's link is inactive and would never start); keep the `id`, so the links stay.
- It does not: insert it with a `uuid4` id, `type='stdio'`, `is_active=1`, `install_source='manual'`, `is_trusted=1`, and `trusted_at`, `installed_at`, `created_at`, `updated_at` at the current time.
- `command` = the path of `veaf-tools.exe`, `args` = `["mcp"]`, JSON compact like `JSON.stringify` (`separators=(',',':')`).
- `env`: **merge** with the existing one (David, 2026-11-26) — force `VEAF_MCP_PROFILE=compact` and keep the other keys.
Two or more rows named `veaf`: refuse (the name is unique only in the application).

## Which assistants get linked (David, 2026-11-26)

**None by default.** `ai-setup` never adds nor removes a link unless asked.
`--cherry-assistant NAME`, repeatable, links the named assistants (`INSERT OR IGNORE`, `deleted_at IS NULL`); the name is matched exactly, accents, spaces and dash included; an unknown name is a warning, not an error.
**The starting backup holds no MCP server** (David, 2026-11-27, superseding the 2026-11-26 plan of a backup carrying the links): it has the assistants "VEAF - édition de mission" and "VEAF - documentation" and the knowledge base; the user restores it, then runs `veaf-tools ai-setup --cherry-assistant "VEAF - édition de mission"`. The server, holding a personal path, never ships in the backup.

Cherry starts the server again at the next chat request; a restart of Cherry is enough.

## `--only` (David, 2026-11-27)

`ai-setup` sets up every client it finds, so testing Cherry used to rewrite Claude Desktop, Claude Code and the others too. `--only CLIENT`, repeatable, named like `--only` in `mission check` and `recon`, sets up the named clients alone (`CLIENT_KEYS`: `claude-desktop`, `claude-code`, `gemini`, `antigravity`, `codex`, `opencode`, `cherry`); the others are neither read nor written. An unknown name is refused before anything runs; a named client that is not found is `failed`, not a silent success. Without `--only`, nothing changes.

## Tests

Absent → `not_found`; run twice → unchanged; other servers and settings kept; link rows untouched; Cherry open → refusal (process and locked `lockfile`); unexpected columns → refusal and nothing written; two `veaf` rows → refusal; `env` merged with the other keys kept; `--cherry-assistant` links only the named one, a name with accents, spaces and a dash included; `--cherry-data-dir` writes that folder only, and refuses one without database; `--only cherry` runs Cherry alone, refuses an unknown client and fails on an absent one; a backup of the database is made before the write. Use a reference database copied from a real Cherry 2.2.3 and regenerate it for each version tested.

## To measure on David's PC, with Cherry closed then relaunched (do it with him)

- The `lockfile` when Cherry is closed (opens, or is gone).
- A Windows path with `\` in `command` (David's current line uses `/`).
- The full path: `ai-setup`, then Cherry, then a VEAF tool call.
