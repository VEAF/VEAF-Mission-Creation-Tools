# Lot FEAT-EXPORT-BFR-PARSER — `veaf-tools export` as the safe mission parser for the BFR plugin

Status: ✅ done (merged #519)

Branch: `feature/export-bfr-parser` → PR → `develop`

## Context

Follow-up to the closed [FEAT-EXPORT-MISSION](../archive/FEAT-EXPORT-MISSION.md) (merged #516),
which delivered `veaf-tools export <miz>` in JSON/YAML/Markdown using the pure-Python
`luadata` parser (never executes Lua).

The BFR Claude plugin `dcs-mission-tools` ([bfr-claude-plugins](https://github.com/Bullseye-Francophone/bfr-claude-plugins))
currently parses a mission by **running** its `mission`/`dictionary`/`mapResource` files
through a bundled `lua54` interpreter in a `load(src, "t", env={})` sandbox. The sandbox
already blocks RCE (`os`/`io`/`require`/`load` unreachable — verified empirically), so this
is **not** an active-RCE fix. The real gains:

- **Principle** *parse ≠ interpret*: reading data must execute nothing.
- **DoS**: the Lua sandbox has no timeout (string-metatable / loop bombs are unbounded).
- **New capability**: the plugin cannot unzip; via veaf-tools it can analyze **any** `.miz`
  (downloaded from a forum, received in DM), not only an extracted VEAF source tree.

Architecture decision (« Endpoint A »): **veaf-tools becomes the sole parser** of mission
data; the plugin keeps `lua54` **only** as a runtime to run its `.lua` checks. veaf-tools
will be **bundled** in the plugin (×3 platforms), like `lua54`.

## Goal

Make `veaf-tools export` a drop-in, deterministic JSON parser the plugin can consume:

1. `export <input>` auto-detects a **`.miz`** (zip) **or** an extracted **mission folder**.
2. The JSON gains a frozen, documented **contract**: `schemaVersion` + a deterministic
   **array/object rule** so the plugin's numeric indexing (`#trigrules`, `ipairs(trig.actions)`)
   works after JSON→Lua decoding.
3. For a `.miz`, embedded resources (scripts, `l10n/DEFAULT/*`) are **extracted** so the
   plugin can run its checks without unzipping.

The plugin side (a JSON→Lua decoder + rerouting its loader) is **out of scope** here: this
lot only **specifies the contract** (`doc/developer/export-json-contract.md`) for Dup to
implement in the plugin repo.

## The `keep_as_dict` question (resolved)

`read_miz` parses `mission` with `keep_as_dict=["trig","trigrules"]` (`miz_tools.py:137`),
forcing those subtrees to int-keyed **dicts**. This is **load-bearing**, not arbitrary: the
mission builder mutates `trig`/`trigrules` by 1-based integer key — shifting all entries up
by N, inserting VEAF triggers at a rank, deleting by index
(`mission_builder_worker.py:860,1639`) — and an int-keyed dict re-serializes to the explicit
`[n]=…` Mission-Editor form. Doing that on a Python list is unsafe (0-based, no gaps).

→ We **keep** `keep_as_dict` and the internal representation untouched. The whole mapping is
confined to the **JSON serialization boundary** (`to_json`), so the builder/parser and the YAML
export's native integer keys are untouched (zero regression risk).

**schemaVersion 2 (key-type-lossless).** Dup's harness found that a numeric-string-key heuristic
can't be correct: real missions carry, often in the same table, sparse-int keys (`payload.pylons`),
mixed int+string keys (`callsign = {[1],[2],[3],["name"]}`), and string-numeric keys
(`failures = {["10"]}`). Because JSON object keys are always strings, the type is lost. The contract
therefore emits: contiguous `1..n` → **array**; all-string keys → **object** (verbatim, no coercion
— fixes `failures`); any integer key in a non-sequence → a **`__luaTable__` envelope**
`{"__luaTable__": [[key, value], …]}` whose pair keys are JSON numbers (Lua int) or JSON strings
(Lua string). JSON's own number/string distinction carries the type, so the plugin decoder never
guesses. (v1's coercion is withdrawn.)

## User Stories

1. As the BFR plugin, I want to feed any `.miz` **or** mission folder to `veaf-tools export`
   and get a deterministic JSON object, so I never run untrusted Lua to read mission data.
2. As the plugin, I want numerically-indexed tables (`trigrules`, `trig.actions/conditions/flag`,
   groups/countries/zones) as JSON **arrays**, so `#t`/`ipairs` work after decoding.
3. As Dup, I want a written contract (schema + array/object rule + decoder requirements) so my
   JSON→Lua decoder reproduces today's `load()` output **table-for-table**.

## Tickets

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-EXPORT-BFR-PARSER-001 | **Contract spec** (deliverable for Dup): `doc/developer/export-json-contract.md` — top-level `{schemaVersion, theatre, mission, dictionary, mapResource}`, deterministic array/object rule, sparse/mixed-key handling, JSON→Lua decoder requirements (integer-string key coercion), parity guarantee, `schemaVersion` bump policy. `.en` mirror. | `doc/developer/`, `doc/developer/*.en.md` | docs | ✅ |
| FEAT-EXPORT-BFR-PARSER-002 | **Array-ness normalizer + `schemaVersion`**: export-only pass converting any contiguous-`1..n` int-keyed dict to a JSON array; add `schemaVersion` at top level. Builder/parser untouched. TDD: unit tests on contiguous, sparse, mixed, empty, nested. | `mission_tools/mission_exporter.py`, `test/python/` | feat | ✅ |
| FEAT-EXPORT-BFR-PARSER-003 | **`export <input>` auto-detects `.miz` or folder**: folder path reads loose `mission`, `l10n/DEFAULT/{dictionary,mapResource}` via `luadata` (no zip), aligned with the VEAF `src/mission/` layout. TDD on both inputs. | `veaf_tools/commands/export.py`, `mission_tools/`, `test/python/` | feat | ✅ |
| FEAT-EXPORT-BFR-PARSER-004 | **Resource extraction** (`.miz` input): extract embedded `.lua` scripts and `l10n/DEFAULT/*` (sounds/images) to a sidecar output dir mirroring the archive layout, so the plugin runs checks without unzipping. TDD on a small real `.miz`. | `veaf_tools/commands/export.py`, `mission_tools/`, `test/python/` | feat | ✅ |
| FEAT-EXPORT-BFR-PARSER-005 | **Parity gate**: round-trip test asserting the exported object reproduces, table-for-table (array-ness + key types), what the plugin's `load()` produces — incl. a **sparse** table case (deleted group/zone leaving `{[2]=,[5]=}`). | `test/python/` | test | ✅ |

## Out of Scope

- Plugin-side code (JSON→Lua decoder, loader rerouting, bundling): owned by the BFR repo.
- Touching `keep_as_dict` / the trigger-injection internals.
- Changing the YAML/Markdown formats (JSON is the machine contract).

## Further Notes

- Security invariant preserved: the export path **never** executes Lua (FEAT-EXPORT-MISSION-004 guard still holds).
- Lockstep: if `export` output shape changes, keep the contract doc and `--help`/i18n strings aligned.
