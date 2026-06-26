# `veaf-tools export` — JSON contract for the BFR `dcs-mission-tools` plugin

> **Audience**: developers of the BFR Claude plugin `dcs-mission-tools`
> ([bfr-claude-plugins](https://github.com/Bullseye-Francophone/bfr-claude-plugins)) who consume
> `veaf-tools export --format json` instead of running mission files through `lua54`.
> This document is the **frozen contract** between the two tools.
>
> **schemaVersion: 2.**

## Why this exists

`veaf-tools` parses a `.miz`'s `mission` / `dictionary` / `mapResource` files with a **pure-Python**
`luadata` state machine — it **never executes Lua** (`luadata/serializer/unserialize.py`). Exporting
that parse as JSON lets the plugin read **any** mission (a `.miz` from a forum, a DM, an extracted
folder) without running untrusted Lua. The plugin keeps `lua54` **only** to run its own `.lua` checks.

The single hard problem is faithfully mapping **Lua tables** to **JSON** and back. JSON object keys
are **always strings**, so a plain JSON object cannot tell a Lua **integer** key from a Lua **string**
key — and DCS missions carry both, sometimes in the *same* table:

- **sparse integer keys** — `payload.pylons = {[1]=,[2]=,[8]=,[11]=}` (pylon numbers skip gaps);
- **mixed keys** — `callsign = {[1]=,[2]=,[3]=,["name"]="Colt11"}`;
- **string-numeric keys** — `failures = {["10"]=,["11"]=}` (DCS failure ids are strings).

A heuristic that "coerces numeric-string keys to integers" is therefore **impossible to get right**: it
breaks `failures` (real strings) while a "keys are always strings" rule breaks `pylons` and the integer
part of `callsign`. The contract below removes all guessing by **preserving the key type in the JSON
itself**, using JSON's native number-vs-string distinction.

## 1. Top-level shape

```json
{
  "schemaVersion": 2,
  "theatre": "Caucasus",
  "mission": { "...": "the parsed `mission` table" },
  "dictionary": { "DictKey_...": "..." },
  "mapResource": { "ResKey_...": "filename.lua" }
}
```

- `schemaVersion` (integer) — **always present, first**, currently **2**. See §5.
- `theatre` — string (or `null` if absent).
- `mission`, `dictionary`, `mapResource` — the parsed tables, mapped per §2. `dictionary` and
  `mapResource` are string→string maps and always serialize as JSON **objects**.

## 2. Table mapping rule (deterministic, key-type-lossless)

For each Lua table, exactly one of these forms is emitted:

| Lua table | JSON form | When |
|---|---|---|
| **Sequence** | JSON **array** | keys are exactly the contiguous integers `1..n` (n ≥ 1) |
| **String record** | JSON **object** | every key is a string |
| **Integer / mixed table** | **`__luaTable__` envelope** | at least one integer key, and not a pure sequence |
| **Empty** | JSON `{}` | no keys (parity-neutral, see §3) |

The envelope is a single-key object whose value is an array of `[key, value]` pairs:

```json
{ "__luaTable__": [ [1, "..."], [2, "..."], [8, "..."], ["name", "..."] ] }
```

Each **pair key** is a JSON **number** for a Lua integer key, a JSON **string** for a Lua string key.
JSON's own number/string distinction carries the type, so the decoder never guesses. Guarantees:

- Integer pair keys are JSON **integers** (`1`, never `1.0`) — a Lua integer key, not a float.
- Each pair is a JSON array of **exactly two** elements; `pair[0]` is a **number or a string** only.

### Worked examples

```json
"trigrules": [ {"comment": "init"}, {"comment": "win"} ],
"trig": { "actions": [ "a_do_script(...)" ], "flag": [ true ] },
"pylons":   { "__luaTable__": [[1,"AIM-9"],[2,"AIM-120"],[8,"fuel"],[11,"AIM-9"]] },
"callsign": { "__luaTable__": [[1,169],[2,1],[3,1],["name","Colt11"]] },
"failures": { "10": {"enable": false}, "11": {"enable": true} }
```

Numerically-indexed sequences (`trigrules`, `trig.actions/conditions/flag`, groups/countries/zones)
stay arrays, so `#t` / `ipairs` work after decoding. `failures` stays a string-keyed object — **never
coerced**.

## 3. Empty tables

An empty Lua table `{}` exports as JSON `{}`. This is **parity-neutral**: a JSON `{}` and a JSON `[]`
both decode to an empty Lua table where `#t == 0` and `next(t) == nil`. The decoder must yield an empty
Lua table for **both**.

## 4. Scalars, strings, encoding

- Lua numbers → JSON numbers; Lua booleans → JSON `true`/`false`.
- Lua strings → JSON strings, **UTF-8, not ASCII-escaped** (`ensure_ascii=false`).
- Absent / `nil` values are not present (`theatre` may be `null`).
- **Key/pair order is not semantically significant**; decoders must not depend on it.

## 5. `schemaVersion` and compatibility

- `schemaVersion` is an integer, **bumped on any breaking change** to this contract. The plugin
  **must** read it and refuse / warn on an unknown version rather than mis-reading silently.
- Current version: **2** (v1 used a numeric-string-key coercion heuristic and is withdrawn).

## 6. Decoder requirements (summary, plugin side)

A conforming JSON→Lua decoder:

1. JSON **array** → Lua sequence with integer keys `1..n`.
2. JSON **object** *without* a sole `__luaTable__` key → Lua table with the keys **verbatim as
   strings** (no numeric coercion — this is what keeps `failures` correct).
3. JSON **object** whose *only* key is `__luaTable__` and whose value is an array of 2-element pairs →
   Lua table built from the pairs: `pair[0]` of JSON type *number* → integer key, *string* → string
   key; `pair[1]` decoded recursively. (Harden against the sentinel collision by requiring exactly this
   shape; otherwise treat the object as a verbatim record.)
4. Empty array **and** empty object → empty Lua table.

With these rules the decoded tables reproduce `load()`'s output **table-for-table** (array-ness *and*
key types), so the plugin's checks return identical findings — and stay correct for *future* checks
that read tables today's checks ignore.

## 7. A note on the JSON shape

With the envelope, `--format json` is a **Lua-faithful** representation: frequent tables like `pylons`
and `callsign` become `__luaTable__` wrappers, which is less ergonomic for a generic JSON consumer
(`jq` …). That is by design — this JSON is the plugin's parser contract. The human-friendly views are
**`--format yaml`** (native integer keys via PyYAML) and **`--format markdown`**.

## 8. Resources (for `.miz` input)

When the input is a `.miz`, `veaf-tools export --extract-dir <dir>` also **extracts** the archive's
embedded resources — `.lua` scripts and `l10n/DEFAULT/*` (sounds/images) — to a sidecar directory
mirroring the archive layout, so the plugin can run its `.lua` checks and resolve `mapResource`
filenames without unzipping. Data files already carried by the JSON are skipped. For an already-extracted
mission folder, nothing is extracted.

## Out of scope (plugin-owned)

The JSON→Lua decoder, rerouting the plugin's `missionLoader.lua` away from `load()`, and bundling
`veaf-tools` live in the BFR plugin repo. This document only **specifies** what veaf-tools guarantees
and what the decoder must do.
