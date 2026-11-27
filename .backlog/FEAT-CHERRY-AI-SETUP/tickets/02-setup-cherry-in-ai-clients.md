# 02 — `setup_cherry` in `ai_clients.py`

Status: 🔄 in-progress — code and tests done (2026-11-27); the three measures on David's PC below are pending.
A `boot-config.json` with a single entry is followed even if it names an old Cherry executable (David, 2026-11-27: too rare to refuse).
The backup uses SQLite's backup API rather than a copy of the `.sqlite` and `-wal` files: it reads the WAL too and gives one self-contained file.
Type: feature
Files: `src/python/veaf-tools/veaf_libs/ai_clients.py`, `test/python/veaf_libs/test_ai_clients.py` (or the file that covers the other clients), the `ai-setup` command if it lists the clients

Add `setup_cherry(...)` and its entry in `setup_all`, with the guarantees of the other clients: idempotent, existing configuration kept, result `not_found` when Cherry is absent.

## Mechanism (from the study, Cherry Studio 2.2.3, `CherryHQ/cherry-studio` tag `v2.2.3`)

Where: `%APPDATA%\CherryStudio\Data\cherrystudio.sqlite`. If `~\.cherrystudio\boot-config.json` holds `app.user_data_path`, use that folder instead; on any doubt, refuse and print the path found.
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

**None by default.** The starting Cherry backup carries the links: the VEAF missions assistant linked to the `veaf` server, the VEAF chatbot not linked (knowledge base only), and Cherry's default assistant "Chéri" empty. `ai-setup` only fixes the executable path and the `env` of the server; it never adds nor removes a link.
`--cherry-assistant NAME`, repeatable, links the named assistants (`INSERT OR IGNORE`, `deleted_at IS NULL`) for an installation without the backup; an unknown name is a warning, not an error.
**The backup must be prepared before it is distributed:** David's own database has "Chéri" linked to the MCP only because he tested with it — remove that link first.

Cherry starts the server again at the next chat request; a restart of Cherry is enough.

## Tests

Absent → `not_found`; run twice → unchanged; other servers and settings kept; link rows untouched; Cherry open → refusal (process and locked `lockfile`); unexpected columns → refusal and nothing written; two `veaf` rows → refusal; `env` merged with the other keys kept; `--cherry-assistant` links only the named one; a backup of the database is made before the write. Use a reference database copied from a real Cherry 2.2.3 and regenerate it for each version tested.

## To measure on David's PC, with Cherry closed then relaunched (do it with him)

- The `lockfile` when Cherry is closed (opens, or is gone).
- A Windows path with `\` in `command` (David's current line uses `/`).
- The full path: `ai-setup`, then Cherry, then a VEAF tool call.
