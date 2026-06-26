# `veaf-tools export` — JSON contract for the BFR `dcs-mission-tools` plugin

> **Audience**: developers of the BFR Claude plugin `dcs-mission-tools`
> ([bfr-claude-plugins](https://github.com/Bullseye-Francophone/bfr-claude-plugins)) who consume
> `veaf-tools export --format json` instead of running mission files through `lua54`.
> This document is the **frozen contract** between the two tools.

## Why this exists

`veaf-tools` parses a `.miz`'s `mission` / `dictionary` / `mapResource` files with a **pure-Python**
`luadata` state machine — it **never executes Lua** (`luadata/serializer/unserialize.py`). Exporting
that parse as JSON lets the plugin read **any** mission (a `.miz` from a forum, a DM, an extracted
folder) without running untrusted Lua. The plugin keeps `lua54` **only** to run its own `.lua` checks.

The single hard problem is faithfully mapping **Lua tables** to **JSON** and back, because:

- A Lua sequence `{[1]=,[2]=,…}` supports `#t` and `ipairs`. The plugin relies on this for
  `trigrules`, `trig.actions/conditions/flag`, and the group/country/zone arrays.
- JSON has **no integer keys**. A naive `{1:…}` → `{"1":…}` mapping yields **string** keys in Lua
  (`#t == 0`, `ipairs` iterates nothing) → the checks silently break.

The contract below makes the mapping deterministic on the veaf-tools side and pins the **two rules**
the plugin's JSON→Lua decoder must follow to restore parity.

## 1. Top-level shape

```json
{
  "schemaVersion": 1,
  "theatre": "Caucasus",
  "mission": { "...": "the parsed `mission` table" },
  "dictionary": { "DictKey_...": "..." },
  "mapResource": { "ResKey_...": "filename.lua" }
}
```

- `schemaVersion` (integer) — **always present, first**. See §6.
- `theatre` — string (or `null` if absent).
- `mission`, `dictionary`, `mapResource` — the parsed tables, mapped per §2.

`dictionary` and `mapResource` are string→string maps and always serialize as JSON **objects**.

## 2. Array vs object rule (deterministic)

A Lua table is emitted as a JSON **array** **iff its keys are exactly the contiguous integers
`1..n`** (n ≥ 1). Every other table is a JSON **object** with string keys.

| Lua table (as parsed) | JSON output | Rationale |
|---|---|---|
| `{[1]=a,[2]=b,[3]=c}` (sequence) | `["a","b","c"]` (**array**) | `#t`, `ipairs` work directly after decoding |
| `{[2]=a,[5]=b}` (**sparse**) | `{"2":"a","5":"b"}` (**object**) | not contiguous → can't be a JSON array; see §3 |
| `{[1]=a,["x"]=b}` (**mixed**) | `{"1":"a","x":"b"}` (**object**) | mixed key types → object; see §3 |
| `{["a"]=1,["b"]=2}` (record) | `{"a":1,"b":2}` (**object**) | natural object |
| `{}` (empty) | `{}` (**object**) | parity-neutral; see §4 |

This covers the tables the plugin indexes numerically — `trigrules`, `trig.actions`,
`trig.conditions`, `trig.flag`, and the `group` / `country` / `zones` arrays — which all come out as
**arrays**.

### Worked example — `trigrules` and `trig`

Parsed mission (conceptually):

```lua
trigrules = { [1] = {...rule1...}, [2] = {...rule2...} }
trig      = { actions    = { [1]="a_do_script(...)" },
              conditions = { [1]="return true" },
              flag       = { [1]=true } }
```

Exported JSON:

```json
{
  "trigrules": [ {"...rule1...": true}, {"...rule2...": true} ],
  "trig": {
    "actions":    [ "a_do_script(...)" ],
    "conditions": [ "return true" ],
    "flag":       [ true ]
  }
}
```

`trig` itself is a record (string keys) → object; each of its sub-tables is a `1..n` sequence → array.
After decoding, `#mission.trigrules`, `ipairs(mission.trig.actions)` behave as they do today.

## 3. Sparse and mixed tables — the decoder's job

A table that is **not** a contiguous `1..n` sequence cannot be a JSON array, so it ships as an object
with **string** keys. This is the only case where JSON loses the integer-key nature.

To restore parity, the plugin's JSON→Lua decoder **must coerce canonical integer-string keys back to
Lua integer keys** when building a table from a JSON object:

- A key matching `^-?%d+$` with **no leading zeros** (except the single `"0"`) → use the integer as
  the Lua key.
- Any other key → keep the string key.

So `{"2":a,"5":b}` decodes to the native Lua table `{[2]=a,[5]=b}`, identical to what `load()` produced.

> `#t` and `ipairs` on a sparse table are **undefined** in Lua anyway, so the contract guarantees
> **value/key parity**, not sequence-length parity, for sparse tables — exactly matching `load()`.

## 4. Empty tables

An empty Lua table `{}` is ambiguous (array or record). It exports as JSON `{}`. This is
**parity-neutral**: a JSON `{}` **and** a JSON `[]` both decode to an empty Lua table where
`#t == 0` and `next(t) == nil`. The decoder must yield an empty Lua table for **both** `{}` and `[]`.

## 5. Scalars, strings, encoding

- Lua numbers → JSON numbers (integers stay integral, e.g. coordinates as floats).
- Lua booleans → JSON `true`/`false`.
- Lua strings → JSON strings, **UTF-8, not ASCII-escaped** (`ensure_ascii=false`). Decoders must read UTF-8.
- Absent / `nil` values are simply not present (no JSON `null` for table members; `theatre` may be `null`).
- **Key order is not significant.** Decoders must not depend on member order.

## 6. `schemaVersion` and compatibility

- `schemaVersion` is an integer, **bumped on any breaking change** to this contract (shape, the
  array/object rule, key semantics). Additive, backward-compatible changes do **not** bump it.
- The plugin **must** read `schemaVersion` and refuse / warn on an unknown major version rather than
  mis-reading silently.
- Current version: **1**.

## 7. Decoder requirements (summary, plugin side)

A conforming JSON→Lua decoder:

1. JSON **array** → Lua sequence with integer keys `1..n`.
2. JSON **object** → Lua table; for each key, if it is a canonical integer string (§3) use the
   **integer** Lua key, else the **string** key.
3. Empty array **and** empty object → empty Lua table.
4. Numbers/booleans/strings → their Lua equivalents; UTF-8 strings.

With these rules, the decoded tables reproduce today's `load()` output **table-for-table** (array-ness
and key types), so the plugin's existing checks return identical findings — the validation criterion #1.

## 8. Resources (for `.miz` input)

When the input is a `.miz`, `veaf-tools export` also **extracts** the archive's embedded resources —
`.lua` scripts and `l10n/DEFAULT/*` (sounds/images) — to a sidecar directory mirroring the archive
layout, so the plugin can run its `.lua` checks and resolve `mapResource` filenames without unzipping.
The JSON object above stays the data pivot; `mapResource` maps resource keys to the extracted filenames.

When the input is an already-extracted mission folder, resources are already loose and nothing is extracted.

## Out of scope (plugin-owned)

The JSON→Lua decoder, rerouting the plugin's `missionLoader.lua` away from `load()`, and bundling
`veaf-tools` are implemented in the BFR plugin repo. This document only **specifies** what veaf-tools
guarantees and what the decoder must do.
