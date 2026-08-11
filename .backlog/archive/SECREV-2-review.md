# VEAF Mission Creation Tools — Full Code & Documentation Review

**Scope.** Python build tooling (`src/python/`, `veaf_build/`, ~26 kLOC), VEAF-owned Lua runtime scripts (`src/scripts/veaf`, `src/scripts/Hooks`, `src/scripts/other`, ~57 kLOC), and bilingual documentation (`doc/**` FR + EN, plus root/`docs/`). Vendored third‑party code (`src/scripts/community/*`, `luadata`) was inspected only for the security surface where VEAF code trusts its output, not for style.

**Method.** 20 specialised reviewers fanned out across the tree; every security/bug finding of medium severity or above was then handed to an independent *adversarial* verifier that re‑read the code and tried to refute it. 6 findings were refuted and dropped. The two CRITICAL and the top HIGH security findings were additionally re‑confirmed by hand at the source. Severities below are **post‑verification**.

**Headline.** The design‑time Python tooling is mature and well‑hardened (the ZIP path in `safe_zip.py`, the AST‑whitelisted arithmetic evaluator, the pure‑Python Lua parser). **The real risk lives in the Lua runtime and, above all, in the multiplayer server hook.** Two CRITICAL, confirmed, *pre‑authentication* remote‑code‑execution vectors exist in `VEAF-Server-hook.lua`: a connecting player's **name** is concatenated into Lua source that the server then executes. Everything else is downstream of a handful of repeating patterns.

---

## 1. Executive summary

### 1.1 Ship‑stoppers (fix before the next public‑server release)

| ID | Severity | Where | One line |
|----|----------|-------|----------|
| VMR‑001 | 🔴 Critical | `Hooks/VEAF-Server-hook.lua:473` | Player name / command interpolated unescaped into `a_do_script([===[…]===])` → arbitrary mission‑env Lua (level ≥ 1). |
| VMR‑002 | 🔴 Critical | `Hooks/VEAF-Server-hook.lua:216` | **Pre‑auth**: merely *connecting* with a crafted name runs attacker Lua via `registerUser("%s",…)`. No level required. |
| VMR‑004 | 🟠 High | `veaf/veafRadio.lua:755` | Player marker text reaches `os.execute()` with `-f`/`-m` injected **unquoted** → OS command injection on the server host (when SRS/STTS is enabled). |
| VMR‑003 | 🟠 High | `veaf/veafGroundAI.lua:599` | Destructive artillery/marker verbs run with **no `veafSecurity` check** — any player can task real fire missions at chosen coordinates. |

These four share one root cause: **untrusted player‑controlled text is turned into executed code (Lua or a shell command) without escaping or an authorization gate.** VMR‑001/002 are the priority — the server hook runs in the DCS host process and the name vector needs no VEAF pilot level at all.

### 1.2 High‑value correctness bugs

- **VMR‑005** (`mission_builder_worker.py:869`) — the dcs‑bridge trigger injection shifts trigger indices but does **not** rewrite the `mission.trig.func[N]` self‑references, silently breaking *every* existing trigger's `funcStartup` when the bridge is enabled.
- **VMR‑006** (`dcs_weather_converter.py:151`) — the "fetch live METAR from ICAO" feature has been **silently non‑functional** against the pinned `avwx-engine` 1.9 API: it never fetches and always returns defaults.
- **VMR‑016** (`dcs_weather_converter.py:246`) — the manual METAR parser silently **drops sub‑zero temperatures** (ignores METAR's `M` minus convention).

### 1.3 Overall posture

| Area | Verdict |
|------|---------|
| Python archive / path / deserialization hardening | **Strong** — `safe_zip` blocks Zip‑Slip + symlinks + zip‑bombs; `luadata` is a pure byte‑state‑machine (no `eval`/`loadstring`); the time‑expression evaluator is AST‑whitelisted. |
| Python correctness & typing | **Good** — a few real bugs (weather, dcs‑bridge), otherwise well‑typed and documented. |
| Lua runtime robustness | **Fragile at the edges** — many marker‑command paths turn hostile/edge text into runtime errors that crash the command handler (DoS‑class, not RCE). |
| Lua / server authorization model | **The weak spot** — inconsistent gating (some modules gate, `veafGroundAI` doesn't) and unsafe code generation in the hook. |
| Documentation (FR/EN) | **Broad but drifting** — real FR↔EN divergences, stale counts, broken links, and one dangerous factual error (coalition IDs reversed, VMR‑014). |

---

## 2. At-a-glance dashboards

### 2.1 By severity (post-verification)

| Severity | Count |
|---|---|
| 🔴 Critical | 2 |
| 🟠 High | 6 |
| 🟡 Medium | 24 |
| ⚪ Low | 95 |
| 🔵 Info | 13 |
| **Total** | **140** |

### 2.2 By language × suggestion type

| Language | Security flaw | Error / bug | Optimization | Refactoring | Readability | Documentation | Total |
|---|---|---|---|---|---|---|---|
| **Python** | 8 | 31 | 4 | 3 | 6 | 0 | **52** |
| **Lua** | 10 | 44 | 2 | 2 | 4 | 0 | **62** |
| **Doc** | 1 | 5 | 0 | 0 | 0 | 20 | **26** |


### 2.3 By verification verdict

| Verdict | Meaning | Count |
|---|---|---|
| CONFIRMED | Adversarial verifier reproduced the defect against the code | 34 |
| PLAUSIBLE | Real but context-dependent | 10 |
| UNVERIFIED | Lower-stakes (optimization/readability/doc/low-sev) — reviewer-asserted, not adversarially re-checked | 96 |

_6 security/bug findings were **REFUTED** by the verifier and dropped from the catalog (see Appendix B)._

## 3. Who each finding helps (by role)

A finding can help several roles. Counts below; the ID lists point into the catalog (§6).

| Role | Security | Bugs | Other | Total |
|---|---|---|---|---|
| **Server admin** | 17 | 14 | 5 | 36 |
| **Mission maker** | 12 | 49 | 15 | 76 |
| **Developer** | 5 | 51 | 27 | 83 |
| **Pilot** | 7 | 19 | 5 | 31 |


**Server admin — notable items (critical/high/medium):** VMR-001, VMR-002, VMR-003, VMR-004, VMR-009, VMR-010, VMR-011, VMR-012, VMR-013, VMR-017, VMR-025, VMR-030

**Mission maker — notable items (critical/high/medium):** VMR-003, VMR-004, VMR-005, VMR-006, VMR-007, VMR-008, VMR-009, VMR-010, VMR-011, VMR-012, VMR-014, VMR-015, VMR-016, VMR-017, VMR-018, VMR-019, VMR-020, VMR-021, VMR-022, VMR-024, VMR-025, VMR-029, VMR-030, VMR-031, VMR-032

**Developer — notable items (critical/high/medium):** VMR-005, VMR-006, VMR-009, VMR-010, VMR-012, VMR-014, VMR-015, VMR-018, VMR-020, VMR-021, VMR-022, VMR-023, VMR-024, VMR-026, VMR-027, VMR-028

**Pilot — notable items (critical/high/medium):** VMR-001, VMR-002, VMR-003, VMR-004, VMR-019, VMR-023, VMR-025, VMR-032


## 4. Cross‑cutting themes (fix the pattern, not just the instance)

**Theme A — "Untrusted text → executed code" (the dominant security theme).**
The same anti‑pattern recurs at five layers: the server hook builds Lua source from player names/commands (VMR‑001/002); `veafRadio` builds a shell command from marker text (VMR‑004); the Python `lua_config_generator` (VMR‑012) and `spawn_data_emitter` (VMR‑010) interpolate `mission.yaml`/spawn strings into generated Lua with only partial escaping; `dcs-fiddle-server` (VMR‑013) runs arbitrary Lua from unauthenticated HTTP. The project already *has* the right tool for the Python side (`_emit_lua_string` / `_lua_long_string`, added in the FIX‑ASSETS‑NEWLINE lot) — it is simply **not applied everywhere**. Recommendation: a single, always‑used "emit safe Lua literal" helper on the Python side (route *all* string interpolation through it), and `string.format('%q', …)` (or a serializer) for every value the server hook injects.

**Theme B — Inconsistent marker‑command authorization.**
`veafCommands.dispatchMarker` deliberately delegates the security decision to each handler. Most honour it (`veafCasMission` → L9, `veafTransportMission` → L1); `veafGroundAI` (VMR‑003) and the SRS path in `veafRadio` (VMR‑004) do not. Recommendation: make the gate a positive obligation — a shared wrapper that *requires* a declared security level, so a handler that forgets fails closed instead of open.

**Theme C — Marker‑text parsing crashes (DoS).**
A long tail of medium/low bugs (VMR‑019/025 and siblings) share the shape "player omits/garbles a parameter → `tonumber(nil)` / `string.format('%d', nonNumber)` / bad table iteration → the whole marker handler errors out." Recommendation: validate‑and‑default parsed marker parameters in the shared parser, not per call‑site.

**Theme D — Fail‑open integrity & unbounded fetches.**
The updater's checksum verification silently passes when metadata is missing (VMR‑011); the dcs‑bridge and updater download and execute remote payloads with no size cap / integrity check (VMR‑009 decompression, plus the bridge/updater fetch findings). Recommendation: fail *closed* when integrity material is absent, and cap+verify every fetched artifact.

**Theme E — Documentation drift.**
Real, checkable divergences: English guides linking to French pages (VMR‑008), stale file/test counts (VMR‑027/028), broken ToC/relative links (VMR‑026/029), and a reversed coalition‑ID table that will mislead every integrator (VMR‑014). Recommendation: a CI doc‑lint that (a) checks `.en.md` internal links resolve to `.en.md`, and (b) treats the FR/EN pair as a structural diff.

---

## 5. Suggested remediation order

1. **Escape the server hook** (VMR‑001, VMR‑002) — smallest change, largest risk reduction; `%q` every injected value. *Effort: small.*
2. **Gate + sanitize the runtime command paths** (VMR‑003 GroundAI gate, VMR‑004 SRS whitelist/quote). *Effort: small–medium.*
3. **Centralize safe‑Lua emission on the Python side** (VMR‑010, VMR‑012). *Effort: medium.*
4. **Fix the three high‑impact bugs** (VMR‑005 dcs‑bridge indices, VMR‑006 live METAR, VMR‑016 sub‑zero temps). *Effort: small–medium.*
5. **Harden fetch/integrity** (VMR‑009 size cap on `read_miz`, VMR‑011 fail‑closed checksum). *Effort: small.*
6. **Doc‑lint pass** for the confirmed divergences/errors (esp. VMR‑014 coalition IDs). *Effort: small.*
7. Work down the medium/low DoS‑class marker‑parsing crashes via a shared validating parser (Theme C).


## 6. Full findings catalogue

Grouped by **language**, then **functional theme**. Each entry: severity · type · verdict · roles · effort.


---

## 🐍 Python — 52 findings

### Python · Trigger injection

#### VMR-005 — dcs-bridge injection shifts trigger indices but leaves funcStartup self-references off by one
🟠 **HIGH** · Error / bug · verdict **CONFIRMED** · effort medium · roles: mission-maker, developer  
`src/python/veaf-tools/mission_builder/mission_builder_worker.py:869`  

**Issue.** inject_dcs_bridge_trigger() shifts every existing trig category entry up by 1 (`{k + 1: v ...}`) to make room for the bridge trigger at index 1, but it does NOT rewrite the Lua text of the shifted triggers. The `funcStartup` (and any `conditions`/`actions`) strings contain hardcoded index references like `if mission.trig.conditions[1]() then mission.trig.actions[1]() end`. After the shift, the trigger whose key becomes 2 still executes `conditions[1]()`/`actions[1]()`, which now points at the bridge trigger. Every previously-inserted trigger therefore invokes the wrong trigger's condition/action pair. Contrast insert_veaf_triggers(), which carefully rewrites these `[old_key]`→`[new_key]` references via regex (lines 1607-1620). This makes dcs_bridge.enabled builds load-broken.  

**Evidence.**
```
for category_name, category_data in trig.items():
    if isinstance(category_data, dict):
        trig[category_name] = {k + 1: v for k, v in category_data.items()}
... 
trig["funcStartup"][1] = "if mission.trig.conditions[1]() then mission.trig.actions[1]() end"  # existing funcStartup[k+1] still says conditions[k]
```

**Fix.** Reuse the same index-rewrite logic as insert_veaf_triggers (regex-substitute `[old]`→`[old+1]` inside every string category value) when shifting for the bridge, or route the bridge through the same VeafTriggerSpec insertion path so the shift/rewrite stays in one place.

> _Verifier:_ Verified in mission_builder_worker.py. inject_dcs_bridge_trigger() (lines 869-879) shifts every trig category dict by +1 (`{k + 1: v ...}`) but never rewrites the Lua text inside the shifted funcStartup/conditions/actions strings. Those strings hardcode indices: funcStartup entries are `"if mission.trig.conditions[i]() then mission.trig.actions[i]() end"` (produced at line 1590 for the VEAF triggers). The build pipeline calls insert_all_veaf_triggers() first (line 1805, active by default when no

#### VMR-056 — _next_trigger_index assumes every trigger key is integer-convertible
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/spawn_data_injector/spawn_data_injector_worker.py:80`  

**Issue.** int(k) is applied to every key of trigrules and of each trig sub-category. DCS trigger tables are normally numerically keyed, but trig can also carry non-numeric keys (e.g. 'actions'/'conditions'/'flag'/'funcStartup' are dict-valued and iterated only when isinstance(category, dict) — good — but any string key inside those sub-dicts, or a stray string key in trigrules, makes int() raise ValueError and aborts injection). The code is defensive about dict-vs-non-dict but not about non-integer keys.  

**Evidence.**
```
line 80: indices.extend(int(k) for k in trigrules)
line 83: indices.extend(int(k) for k in category)  — no isdigit()/try guard around int().
```

**Fix.** Filter to numeric keys before converting, e.g. `int(k) for k in trigrules if str(k).lstrip('-').isdigit()` (and same for category), so a non-numeric key doesn't crash index computation.

### Python · Weather fetch

#### VMR-006 — Live METAR fetch never actually fetches; always returns defaults
🟠 **HIGH** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/weather_injector/weather/dcs_weather_converter.py:151`  

**Issue.** With avwx-engine pinned to 1.9.x (poetry.lock: avwx_engine 1.9.8), constructing `Metar(airport_icao)` only creates the report object; it does NOT retrieve live data. Fetching requires an explicit call such as `metar.update()` / `Metar.from_report(...)` / an async fetch. The code reads `metar.temperature`, `metar.wind_speed`, etc. immediately after construction, so every attribute is None and the function falls through to the hard-coded defaults (15C, 5 m/s wind, clear sky). The advertised `airport_icao` feature is therefore silently broken: a mission-maker asking for live weather at KJFK always gets generic defaults with no error.  

**Evidence.**
```
metar = Metar(airport_icao)

        if metar.temperature and metar.temperature.value is not None:  # type: ignore[attr-defined]
            result["temperature"] = metar.temperature.value
```

**Fix.** Call the avwx fetch API before reading fields (e.g. `metar = Metar(airport_icao); metar.update()`), and guard the return so a failed/empty fetch is reported to the user instead of silently substituting defaults.

> _Verifier:_ Verified against the pinned dependency. poetry.lock pins avwx-engine 1.9.8. I extracted that exact wheel and read avwx/current/metar.py, avwx/current/base.py and avwx/base.py. The Metar class docstring explicitly shows the fetch pattern requires an explicit call: `kjfk = Metar("KJFK")` then `kjfk.update()`; construction alone does not retrieve data. Parsed values (temperature, wind_speed, wind_direction, visibility, clouds) live on the MetarData struct exposed as `Metar.data`, NOT as attributes 

#### VMR-069 — Broad `except Exception` around METAR fetch swallows all errors as a warning
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, server-admin  
`src/python/veaf-tools/weather_injector/weather/dcs_weather_converter.py:187`  

**Issue.** The entire live-fetch block is wrapped in `except Exception as e: logger.warning(...)` and then returns the default-weather dict. A network failure, an invalid ICAO, an avwx API change, or a rate-limit is downgraded to a warning and the mission is built with generic default weather. Combined with the fact that the fetch never runs (see the high-severity finding), a mission-maker gets plausible-looking but wrong weather and no build failure.  

**Evidence.**
```
except Exception as e:
        logger.warning(t("weather.converter.metar_fetch_failed", icao=airport_icao, error=str(e)))

    return result
```

**Fix.** Narrow the caught exceptions and surface a real error (or at least a distinct, prominent warning) when an explicitly requested ICAO fetch fails, rather than silently returning defaults.

### Python · Archive hardening

#### VMR-009 — read_miz / write_miz decompress untrusted .miz members with no size cap (decompression-bomb gap)
🟡 **MEDIUM** · Security flaw · verdict **CONFIRMED** · effort medium · roles: server-admin, mission-maker, developer  
`src/python/veaf-tools/mission_tools/miz_tools.py:124`  

**Issue.** read_miz opens each member of an attacker-controlled .miz and reads it fully into memory (read_file_in_archive at line 124: `zip_file.open(file_name).read()`, and unserialize reads the whole decompressed text). write_miz does the same when copying untouched members (`zip_read.read(file_name)` at lines 272/282/287/297/307/317/323). Unlike extract_miz/extract_resources, these paths do NOT go through safe_extract_all, so none of the zip-bomb caps (MAX_ARCHIVE_UNCOMPRESSED_BYTES, MAX_ARCHIVE_ENTRIES) apply. A single crafted member (e.g. a `mission` file that decompresses to gigabytes) is fully materialized in RAM before any check, so a malicious .miz can OOM the tooling. This is the primary read/normalize path — the extractor calls read_miz then write_miz on the raw input (mission_extractor_worker.py:111-112) before extract_miz ever runs.  

**Evidence.**
```
L124 `with zip_file.open(file_name) as file:` then `return file.read().decode("utf-8")` / `unserialize(file,...)`; L257 `with zipfile.ZipFile(mission.file_path, "r") as zip_read:` copying members via `zip_read.read(file_name)` with no cap. Compare safe_zip.py:59-63 which caps declared_total against max_total_bytes.
```

**Fix.** Enforce the same declared-size / member caps (from veaf_libs.safe_zip) before calling ZipInfo.file_size-unbounded read()/open().read() in read_miz and in write_miz's copy path — e.g. reject members whose ZipInfo.file_size (and running total) exceeds the safe_zip limits, or read in bounded chunks.

> _Verifier:_ The finding holds against the actual code. In miz_tools.py, read_miz's inner read_file_in_archive (L123-128) does `zip_file.open(file_name).read().decode(...)` / passes the stream to unserialize which reads the whole decompressed text — no size cap. write_miz copies every untouched member via `zip_read.read(file_name)` (L272/282/287/297/307/317/323), each loaded fully into RAM. Neither path goes through safe_extract_all, so the MAX_ARCHIVE_UNCOMPRESSED_BYTES/MAX_ARCHIVE_ENTRIES caps in safe_zip.

### Python · Spawn-data lua generation

#### VMR-010 — Spawn-data Lua emitter only escapes backslash and double-quote, allowing broken/injectable Lua
🟡 **MEDIUM** · Security flaw · verdict **CONFIRMED** · effort small · roles: developer, mission-maker, server-admin  
`src/python/veaf-tools/spawn_data_injector/spawn_data_emitter.py:52`  

**Issue.** _lua_string() escapes only '\\' and '"'. Any newline, carriage return, or other control character in a string field (description, groupName, unitType, aliases) is emitted verbatim inside a Lua double-quoted literal. In Lua 5.1 a literal newline inside a double-quoted string is a syntax error, and a crafted value can close the string and inject arbitrary Lua that then runs inside DCS via the injected a_do_script_file trigger. These string values come from veaf-units.yaml AND from the per-mission spawn-data file merged in by SpawnDataInjectorWorker (mission_data_file), i.e. third-party/mission-maker-controlled content, so this is untrusted input rendered into executable Lua.  

**Evidence.**
```
def _lua_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'  — no handling of \n, \r, \t or other control chars; the merged mission data reaches here via render_spawn_data_lua()->_render_group_entry()->description/groupName.
```

**Fix.** Escape control characters as well: at minimum map \n->\\n, \r->\\r, \t->\\t (and ideally any char < 0x20 to a \\ddd decimal escape) before quoting. This closes both the syntax-break and the Lua-injection vector.

> _Verifier:_ Verified in src/python/veaf-tools/spawn_data_injector/spawn_data_emitter.py:52-55: _lua_string() only does value.replace("\\","\\\\").replace('"','\\"') and returns f'"{escaped}"' — no handling of \n, \r, \t, or other control characters. The value is rendered inside a Lua double-quoted literal; in Lua 5.1 an unescaped literal newline inside "..." is a syntax error, so a multiline description/groupName produces a broken chunk, and a crafted value can close the string/table and inject additional L

### Python · Update integrity

#### VMR-011 — Checksum verification fails open when release metadata is missing or malformed
🟡 **MEDIUM** · Security flaw · verdict **CONFIRMED** · effort small · roles: server-admin, mission-maker  
`src/python/veaf-tools/veaf-tools-updater.py:685`  

**Issue.** With verify_checksum=True the updater only enforces the SHA-256 when every optional step succeeds: if the published-metadata.json asset is absent (line 712 -> just warns), if it fails to download (line 697 falls through), if the JSON does not parse (line 710 -> warns), or if 'published_zip_sha256' is missing/empty (line 701 guard is skipped), the code proceeds straight to extract_and_install with the UNVERIFIED zip. An attacker (or a compromised release/mirror) who serves published.zip without a valid metadata asset thus bypasses integrity checking entirely while the tool reports success. Integrity verification that a caller explicitly enabled should fail closed, not silently degrade to no verification.  

**Evidence.**
```
if metadata_asset:
    metadata_content = self.download_asset(...)
    if metadata_content:
        try:
            metadata = json.loads(metadata_content)
            published_checksum = metadata.get("published_zip_sha256")
            if published_checksum:
                ... verify ...
        except json.JSONDecodeError:
            logger.warning(t("updater.warn.metadata_parse"))
else:
    logger.warning(t("updater.warn.no_metadata"))
```

**Fix.** When verify_checksum is True, treat a missing/undownloadable/unparseable metadata asset or an absent published_zip_sha256 as a hard failure (return False) instead of a warning. Only skip verification when the user explicitly passed --no-verify-checksum. Keep the warn-and-continue behaviour behind that explicit opt-out.

> _Verifier:_ Read src/python/veaf-tools/veaf-tools-updater.py lines 685-724. The finding is factually correct: verify_checksum defaults to True (line 758: `verify_checksum = not no_verify_checksum`, and constructor default is True at line 161). Under the `if self.verify_checksum:` block (line 685), checksum enforcement only occurs on the fully-happy path. Every degraded branch falls through to extract_and_install (line 716) with the UNVERIFIED zip and returns success (line 721): (a) no metadata asset -> line

#### VMR-057 — Temp verification zip leaks on unexpected exception
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: server-admin  
`src/python/veaf-tools/veaf-tools-updater.py:703`  

**Issue.** The verification temp file 'published_<version>.zip.tmp' is written to CWD and only unlinked on the explicit success/mismatch branches. Any exception other than json.JSONDecodeError between write_bytes and the unlink (e.g. an OSError from verify_file_integrity reading the file, or a KeyboardInterrupt) leaves the multi-hundred-MB temp file behind in the mission folder. The unlink is not in a finally block.  

**Evidence.**
```
temp_zip = Path.cwd() / f"published_{release_version}.zip.tmp"
temp_zip.write_bytes(zip_content)
if not self.verify_file_integrity(temp_zip, published_checksum):
    temp_zip.unlink()
    ...
    return False
temp_zip.unlink()
```

**Fix.** Wrap the write/verify/unlink in try/finally (or use tempfile.NamedTemporaryFile) so the temp zip is always removed. Better still, hash zip_content in memory (hashlib.sha256(zip_content)) and avoid writing a temp file at all.

### Python · Lua config generation

#### VMR-012 — mission.yaml string values are interpolated into generated Lua without escaping (Lua injection / broken output)
🟡 **MEDIUM** · Security flaw · verdict **CONFIRMED** · effort medium · roles: mission-maker, server-admin, developer  
`src/python/veaf-tools/veaf_libs/lua_config_generator.py:376`  

**Issue.** The generator has dedicated safe emitters — _emit_lua_string() (line 393) and _lua_long_string() (line 379) — that pick a valid Lua literal for arbitrary text, but they are only used for a few fields (asset name/description/information, briefings, airwave messages). The overwhelming majority of user-supplied strings from mission.yaml are interpolated straight into the generated veaf-config.lua with f'"{value}"' or via _to_lua_scalar (which for strings just returns f'"{value}"' with no escaping). Any value containing a double-quote, backslash, newline, or ]] either produces syntactically broken Lua or injects arbitrary Lua that then executes inside the DCS process when veaf-config.lua is loaded. This is a real code-execution surface for the mission author and a foot-gun that silently corrupts the build. Affected sites include: _to_lua_scalar strings (line 376) feeding settings: (line 948) and per-module veaf.setConfig values (line 1017); MISSION_NAME (line 902, which is further concatenated into a JSON filename at runtime in veafCombatMission.lua:1517 / veafSpawnAircraft.lua:438); export_path (line 905); era (line 908); language (line 919); password hashes (lines 929, 934); QRA setName/trigger_zone/airport_link (lines 743, 749, 770); Shortcuts name/description/command (lines 512-514); Sanctuary name (line 527); combat-zone friendly_name/zone_name and cap-mission group/menu/briefing (lines 497, 598, 599); AirWave name/description/coords (lines 662-668).  

**Evidence.**
```
def _to_lua_scalar(value: object) -> str:
    ...
    return f'"{value}"'   # line 376 — no escaping of " \\ or newlines
...
lines.append(f'    :setName("{name}")')          # QRA, line 743
lines.append(f'        :setName("{name}")')      # shortcuts, line 512
lines.append(f'veafSecurity.password_L9["{hash_val}"] = true')  # line 929
```

**Fix.** Route every user-supplied string through _emit_lua_string() (and table keys like the password hash through the same) instead of bare f'"{...}"'. Make _to_lua_scalar delegate to _emit_lua_string for str values so settings:/setConfig are covered in one place. Add a test feeding a value containing a double-quote, backslash and newline and assert the generated Lua parses.

> _Verifier:_ The code claim is accurate. I read lua_config_generator.py: _to_lua_scalar (line 376) returns f'"{value}"' with zero escaping of ", \\, newline, or ]]. Safe emitters _emit_lua_string (393) and _lua_long_string (379) exist but are used only for a minority of fields (asset name/desc line 469, combat-zone briefing line 602, airwave messages line 708). The majority of user-supplied strings are interpolated straight in via f'"{value}"' or _to_lua_scalar, exactly as the finding lists: settings (948), 

### Python · Config conversion

#### VMR-015 — Lua-to-YAML converter emits numeric `time`, breaking the downstream string parser
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/weather_injector/utils/lua_converter.py:125`  

**Issue.** The converter writes `version["time"] = LuaToYamlConverter._get_number(target, "time")`, i.e. an int/float, into the YAML. But VersionConfig.time is typed `str | None` and TimeExpressionParser.parse() begins with `expression.strip()`, which raises AttributeError on an int. If a legacy Lua config used a numeric `time`, the converted YAML will crash the weather injector at parse time. Additionally `moment`/`variableForMetar` keys emitted here are not consumed by the current MissionConfig.from_dict (only name/time/date/metar/airport_icao/weather/clearsky), so converted configs referencing named moments produce versions with no usable time.  

**Evidence.**
```
if time := LuaToYamlConverter._get_number(target, "time"):
                        version["time"] = time
```

**Fix.** Emit `time` as a string (str(value)) to match the expression parser, and either map legacy `moment` names to concrete time expressions or document that moments are unsupported so converted files don't silently lose their time.

> _Verifier:_ I traced the full chain and both parts of the claim hold. In lua_converter.py:125-126 the converter writes version["time"] = LuaToYamlConverter._get_number(target, "time"), and _get_number (lines 246-258) returns int or float. In configuration.py:55 MissionConfig.from_dict does time=version_data.get("time") with no coercion, so the numeric value flows unchanged into VersionConfig.time (typed str | None, configuration.py:21). In weather_injector_worker.py:189-191 the worker calls TimeExpressionPa

#### VMR-068 — `_extract_list` escape handling ignores string state and doubled backslashes
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/weather_injector/utils/lua_converter.py:207`  

**Issue.** Unlike the sibling `_extract_table` (which tracks an `escape_next` flag only while `in_string`), `_extract_list` skips the character after ANY backslash regardless of whether it is inside a string, and does not handle a doubled backslash `\\`. A Lua string value containing `\\"` (escaped backslash followed by a real closing quote) will be mis-parsed: the loop skips the second backslash, then treats the following `"` as a string toggle, corrupting brace counting and truncating/dropping target tables. Legacy configs with such weather strings convert incorrectly.  

**Evidence.**
```
# Handle escape sequences
            if i > 0 and content[i - 1] == "\\":
                i += 1
                continue
```

**Fix.** Mirror `_extract_table`'s escape handling: only treat a backslash as an escape when `in_string`, and consume exactly the escaped character via an explicit `escape_next` flag.

#### VMR-111 — `_get_boolean` helper is dead code
⚪ **LOW** · Refactoring · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/weather_injector/utils/lua_converter.py:261`  

**Issue.** `_get_boolean` is defined but never called anywhere in the module (confirmed via grep). The docstring/example format even shows `clearsky`, `dontSetToday`, `dontSetTodayYear` boolean fields in the legacy Lua, but `_parse_lua_config` never extracts them — so the `clearsky` flag (and the dontSetToday semantics) are lost during conversion, and the boolean helper is unused scaffolding.  

**Evidence.**
```
@staticmethod
    def _get_boolean(content: str, key: str) -> bool:
        """Extract boolean value from Lua content."""
```

**Fix.** Either wire `_get_boolean` into `_parse_lua_config` to carry over `clearsky`/`dontSetToday*` into the converted versions, or delete the unused helper.

### Python · Weather parsing

#### VMR-016 — METAR parser silently drops negative (sub-zero) temperatures
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker  
`src/python/veaf-tools/weather_injector/weather/dcs_weather_converter.py:246`  

**Issue.** In METAR, negative temperatures and dewpoints are encoded with an 'M' prefix (e.g. `M05/M10`), not a minus sign. The fallback parser splits on '/' and accepts the value only if `with_temp.lstrip("-").isdigit()`, which only recognizes a literal '-' sign. For any winter/high-altitude METAR like `... M05/M12 ...`, the temperature token is rejected and the mission silently gets the 15C default, producing wrong (much warmer) mission weather with no warning.  

**Evidence.**
```
with_temp = part.split("/")[0]
            if with_temp.lstrip("-").isdigit():
                try:
                    result["temperature"] = float(with_temp)
```

**Fix.** Handle the METAR 'M' minus convention, e.g. strip/replace a leading 'M' with '-' before the isdigit()/float() check (and do the same for the dewpoint half if used).

> _Verifier:_ The claim holds against the actual code. In dcs_weather_converter.py, when a user supplies a metar_string, DCSWeatherConverter.to_dcs_lua_table (line 74-75) calls _extract_metar_values, which at line 217 unconditionally invokes _fallback_metar_parsing — the regex path is ALWAYS used for provided METAR strings, not only when avwx is missing (the docstring at line 226 is misleading on that point). At line 246-247, with_temp = part.split("/")[0] then guards on with_temp.lstrip("-").isdigit(). lstri

#### VMR-070 — Visibility regex matches unrelated 4-digit METAR tokens
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort medium · roles: mission-maker  
`src/python/veaf-tools/weather_injector/weather/dcs_weather_converter.py:266`  

**Issue.** `if part.isdigit() and len(part) == 4` treats any bare 4-digit group as visibility in meters. Several standard METAR groups are 4 pure digits — e.g. a 4-digit pressure remnant or the day/time before the trailing 'Z' if malformed, or a `0000`/`9999` that is fine but also e.g. RVR/coded groups in some formats. Because parsing simply iterates all whitespace tokens with no positional anchoring, the last matching 4-digit token wins and can override the true visibility. This is fragile; a purpose-built METAR library (already a dependency) would be more robust for user strings too.  

**Evidence.**
```
if part.isdigit() and len(part) == 4:
            try:
                result["visibility"] = float(part)
```

**Fix.** Route user-provided METAR strings through avwx's `Metar.from_report(...)` parser (the dependency is already present) instead of the ad-hoc regex, or at least anchor the visibility match to its expected position/format.

### Python · Dcs-bridge download

#### VMR-034 — dcs-bridge auto-download has no size cap or integrity check (unbounded fetch of executed Lua)
⚪ **LOW** · Security flaw · verdict **UNVERIFIED** · effort medium · roles: mission-maker, server-admin  
`src/python/veaf-tools/mission_builder/mission_builder_worker.py:814`  

**Issue.** When dcs_bridge is enabled with no lua_path, the builder downloads dcs-bridge.lua from a hardcoded GitHub raw URL and embeds it verbatim into the mission .miz as a script that runs inside DCS. urlopen() reads the whole response with resp.read() and no maximum size, and there is no checksum/signature verification. A compromised or MITM'd response (or a redirect) becomes arbitrary Lua executed on every player/server that loads the mission, and an oversized response is read fully into memory. The URL is https and pinned to a branch, which mitigates casual tampering, but there is no defense-in-depth (pinned hash / max bytes / opt-in confirmation).  

**Evidence.**
```
with urllib.request.urlopen(_DCS_BRIDGE_DOWNLOAD_URL) as resp:
    content: bytes = resp.read()
```

**Fix.** Read with a bounded size (resp.read(MAX_BYTES) and error if exceeded), and verify a pinned SHA-256 of the expected bridge before embedding. Prefer shipping the bridge as a bundled resource over fetching it at build time.

#### VMR-049 — Auto-downloaded dcs-bridge.lua temp file is never deleted (handle/file leak)
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/python/veaf-tools/mission_builder/mission_builder_worker.py:819`  

**Issue.** resolve_dcs_bridge_file() creates a NamedTemporaryFile(delete=False) to hold the downloaded bridge and returns its path, but nothing ever unlinks it. The bytes are also separately read back into self.dcs_bridge_bytes (inject_dcs_bridge_trigger, line 843) and written into the .miz, so the temp file serves no post-build purpose. Every build with dcs_bridge auto-download leaves an orphan .lua in the system temp dir.  

**Evidence.**
```
tmp = tempfile.NamedTemporaryFile(suffix=".lua", delete=False)
tmp.write(content)
tmp.flush()
tmp.close()
return Path(tmp.name)  # never removed
```

**Fix.** Delete the temp file after the bridge bytes are consumed (e.g. in write_mission/work via try/finally), or avoid the temp file entirely by returning the bytes directly since inject_dcs_bridge_trigger only needs the content.

### Python · Convert-other script renaming

#### VMR-035 — Profile-driven script rename uses replacement verbatim as a filename (path traversal into scripts_dir parent)
⚪ **LOW** · Security flaw · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/mission_builder/other_converter.py:502`  

**Issue.** _normalize_script_names() builds the rename destination as `scripts_dir / new_name` where new_name is a conversion-profile name-rule replacement (ConversionProfile.normalize_script_name returns rule.replacement unchanged). If a profile (bundled or, more importantly, a user-supplied `--profile <path>`) specifies a replacement containing path separators or `..`, `src.rename(dst)` and the later dst.unlink()/exists() operate outside scripts_dir. The custom_scripts path emitted for the loader would also point outside the folder. Profiles are semi-trusted, but a path can be passed on the CLI, so this is an untrusted-input surface.  

**Evidence.**
```
new_name = profile.normalize_script_name(loader.script)
...
dst = scripts_dir / new_name
if src.is_file():
    if dst.exists() and overwrite:
        dst.unlink()
    if not dst.exists():
        src.rename(dst)
```

**Fix.** Reject or basename-strip a replacement that is not a plain filename: e.g. `new_name = Path(new_name).name` and assert it contains no separators before using it, mirroring how custom_scripts paths are reduced to basenames in the builder.

### Python · Self-update

#### VMR-036 — Deferred-update .cmd script interpolates paths without escaping (batch injection)
⚪ **LOW** · Security flaw · verdict **UNVERIFIED** · effort medium · roles: server-admin  
`src/python/veaf-tools/veaf-tools-updater.py:328`  

**Issue.** _launch_deferred_update builds a Windows .cmd file by f-string interpolating current_dir (Path.cwd()) and derived exe names directly into 'cd /d "{current_dir}"' and other quoted commands, then runs it with shell=True. A working-directory path containing a double-quote, caret, percent, or & would break out of the quoting and inject batch commands executed at the updater's privilege. Path.cwd() is not normally attacker-controlled, but the tool is run by end users in arbitrary folders and the value is embedded into an executed script with no escaping.  

**Evidence.**
```
script_content = f"""@echo off
...
cd /d "{current_dir}"
...
subprocess.Popen(str(update_script), shell=True, ...)
```

**Fix.** Avoid shell=True; where a .cmd is required, validate/escape the interpolated paths (reject paths containing " & ^ % or use only the already-computed .name components with a fixed working directory passed via cwd=). At minimum, refuse to generate the script when str(current_dir) contains a double-quote.

### Python · Update download

#### VMR-037 — download_asset does not validate the GitHub-provided download URL scheme/host
⚪ **LOW** · Security flaw · verdict **UNVERIFIED** · effort medium · roles: server-admin  
`src/python/veaf-tools/veaf-tools-updater.py:300`  

**Issue.** download_asset issues requests.get on asset.get('browser_download_url') taken verbatim from the release JSON, and _download_binary_asset writes the response bytes to disk and chmods 0o755. The URL is trusted from the GitHub API payload; if the API endpoint is ever pointed at an attacker-controlled host (e.g. via a tampered GITHUB_API_BASE, a proxy, or a compromised release), an arbitrary URL is fetched and its bytes are written as an executable binary next to the mission. The checksum path only covers published.zip, not the separately-downloaded Unix binaries, which have no integrity check at all.  

**Evidence.**
```
content = self.download_asset(asset.get("browser_download_url"), asset_name)
...
tmp.write_bytes(content)
tmp.chmod(0o755)
os.replace(str(tmp), str(dest))
```

**Fix.** Verify browser_download_url uses https and points at an expected host (github.com / objects.githubusercontent.com) before fetching, and extend checksum/metadata verification to cover the Unix binary assets, not only published.zip.

### Python · Coalition placeholder

#### VMR-047 — _max_ids / _coalition_unit_count assume country is always a list and group containers are dicts
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/python/veaf-tools/mission_builder/coalition_placeholder.py:60`  

**Issue.** ensure_coalitions_populated normalizes each coalition's `country` to a list before scanning, but _max_ids iterates `mission_content.get('coalition', {}).values()` independently and calls `coalition.get('country', [])` directly. If _max_ids is ever called on a not-yet-normalized mission (it is not today, but it is a module-level helper), an empty DCS `country = {}` (dict) would iterate dict keys (strings) and `country.get(category)` would raise. Similarly `_coalition_unit_count` calls `coalition.get('country', [])` and iterates without a dict guard, relying entirely on the caller having normalized first. This couples correctness to call order in a way that is easy to break.  

**Evidence.**
```
for country in coalition.get("country", []):
    for category in _UNIT_CATEGORIES:
        for group in country.get(category, {}).get("group", []):
```

**Fix.** Have _max_ids and _coalition_unit_count coerce/guard the country container themselves (reuse _coerce_country_list or an isinstance(country, dict) skip), so the helpers are safe independent of call order.

### Python · V5 config extraction

#### VMR-048 — Combat-mission / assets extraction comments out from call start, not line start, corrupting the leading text
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`src/python/veaf-tools/mission_builder/config_migrator.py:1044`  

**Issue.** _extract_combat_missions comments the span [call_start, close_pos) where call_start is the position of `veafCombatMission.AddMissionsWithSkillAndScale` (mid-line, not line start) and close_pos is one past the matching `)`. Any code preceding the call on the same first line (indentation aside, e.g. `local x = veafCombatMission.AddMissions...`) is left un-commented while the call body becomes a comment, and any text after `)` on the last line stays live too. Because the first commented line gets a `-- [v6 ...]` prefix only for lines whose .strip() is truthy, a leading `local x =` fragment can end up as dangling live Lua. In convert-v5 the whole file is discarded so impact is limited, but the standalone migrate-config command writes this buffer to disk.  

**Evidence.**
```
for m in list(self._ADD_MISSIONS_RE.finditer(code)):
    call_start = m.start()
    ...
    replacements.append((call_start, close_pos, cm))
...
chunk = content[start:end]
commented = "\n".join(f"-- [v6 extracted to mission.yaml] {line}" ...)
```

**Fix.** Snap `start` back to the beginning of the line (content.rfind('\n',0,call_start)+1) and `end` forward to the end of the last line, as the QRA/sanctuary extractors already do, so whole lines are commented.

### Python · Trigger removal

#### VMR-050 — clear_veaf_triggers deletes trigger indexes without handling the list-shaped trig category
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/python/veaf-tools/mission_builder/mission_builder_worker.py:1156`  

**Issue.** The collection step (lines 1134-1150) handles a trig category that is either a list (enumerate → integer positions) or a dict (items → keys), building a mixed trigger_indexes_to_remove. The removal step (lines 1156-1159) then only does `trigger_category_value.get(trigger_index)` / `del`, which assumes every category is a dict. If any category arrived as a list (the code explicitly anticipates that shape when collecting), `.get` raises AttributeError and the build aborts. The two halves disagree on the container shape, so the list branch of the collector is effectively dead/unsafe.  

**Evidence.**
```
for trigger_category_index, trigger_category_value in mission_triggers.items():
    for trigger_index in trigger_indexes_to_remove:
        if trigger_category_value.get(trigger_index):
            del trigger_category_value[trigger_index]
```

**Fix.** Make removal shape-aware (skip/convert lists, or normalize categories to dicts once up front) consistent with the collection loop, or drop the list branch if trig categories are always dicts in practice.

### Python · Weather conversion

#### VMR-051 — Weather converter drops a version's weather when position lat/lon keys are present but null
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`src/python/veaf-tools/mission_builder/v5_pipeline_converters.py:635`  

**Issue.** convert_weather resolves position via `pos.get('lat', pos.get('latitude'))`. dict.get only falls back to the second lookup when the key is ABSENT; if the source has `lat: null` (explicit null, which JSON/Lua can produce), get returns None instead of trying `latitude`, silently emitting `latitude: null` in the v6 YAML. The reverse (only `latitude` present) works, but a mixed/explicit-null source loses the coordinate. Same pattern for lon/tz.  

**Evidence.**
```
output["position"] = {
    "latitude": pos.get("lat", pos.get("latitude")),
    "longitude": pos.get("lon", pos.get("longitude")),
    "timezone": pos.get("tz", pos.get("timezone")),
}
```

**Fix.** Use an explicit `pos.get('lat') if pos.get('lat') is not None else pos.get('latitude')` (or a small first-non-None helper) so an explicit null still falls back to the alternate key.

### Python · Logging discipline

#### VMR-052 — Bare print() in extractor worker violates logger-only project rule
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: developer, server-admin  
`src/python/veaf-tools/mission_extractor/mission_extractor_worker.py:83`  

**Issue.** Two PermissionError handlers use the native print() instead of veaf_libs.logger, which the project rules explicitly forbid ('Absolute prohibition of using the native print()'). Besides violating the rule, these messages bypass the log file entirely, so a permission failure that silently prevents deleting/moving a mission file during extraction leaves no trace in dcs-independent logs and the error is swallowed (execution continues).  

**Evidence.**
```
L83 `print(f"Permission denied to delete {path}")` and L100 `print(f"Permission denied to move {path} to {new_path}")` inside `except PermissionError:` blocks. The module already imports `from veaf_libs.logger import logger`.
```

**Fix.** Replace both with `logger.warning(...)` (or `logger.error`). Consider whether a permission failure mid-extraction should abort rather than be swallowed.

> _Verifier:_ Verified in mission_extractor_worker.py: line 83 `print(f"Permission denied to delete {path}")` and line 100 `print(f"Permission denied to move {path} to {new_path}")` are both bare native print() calls inside `except PermissionError:` blocks. The module imports `from veaf_libs.logger import logger` (line 20), and logger exposes `.warning()`/`.error()` (veaf_libs/logger.py:92,107), so the compliant alternative is readily available. CLAUDE.md explicitly states "Only use the logger from veaf_libs.

### Python · Atomic write

#### VMR-053 — write_miz temp file left behind and original silently unchanged on partial failure paths
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort medium · roles: developer, mission-maker  
`src/python/veaf-tools/mission_tools/miz_tools.py:247`  

**Issue.** write_miz creates a NamedTemporaryFile with delete=False and opens a *second* ZipFile handle on the same temp_zip_path (line 261) while the outer `temp_file` handle from the `with` at line 247 is still open. On Windows the outer open handle can prevent os.replace/os.unlink of the temp path. More importantly, on any exception the code logs and sets temp_zip_path=None so the original is preserved (good), but the function still returns `mission` normally with no signal to the caller that the write was skipped — callers (e.g. injectors) treat the operation as success even though the .miz on disk is unchanged, producing a silently stale output.  

**Evidence.**
```
L247-253 open temp_file; L261 second `with zipfile.ZipFile(temp_zip_path, "w", ...)`; L329-334 on exception `logger.exception(e); temp_zip_path = None`; L337-340 `if temp_zip_path: os.replace(...)` then `return mission` unconditionally with no error propagated.
```

**Fix.** Either re-raise after logging (so the caller knows the write failed) or return a status; and close/avoid holding the outer NamedTemporaryFile handle while the inner ZipFile writes to the same path.

### Python · Api contract

#### VMR-054 — read_mission_folder produces a DcsMission whose file_path is a directory, unsafe to pass to write_miz
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/mission_tools/miz_tools.py:198`  

**Issue.** read_mission_folder sets `file_path=folder_path` (a directory). If such a DcsMission is later handed to write_miz with miz_file_path=None, write_miz falls back to `miz_file_path = mission.file_path` (line 240), creates the temp file in `miz_file_path.parent` and then does `zipfile.ZipFile(mission.file_path, "r")` on a directory, raising IsADirectoryError/PermissionError deep inside the write. Nothing in the type system flags this; the two read entry points return the same DcsMission type but only one is a valid write source. This is a latent trap for future callers rather than a live bug (current callers pass explicit output paths).  

**Evidence.**
```
L198 `result = DcsMission(file_path=folder_path)` vs read_miz L133 `DcsMission(file_path=miz_file_path)`; write_miz L239-240 `if not miz_file_path: miz_file_path = mission.file_path` then L257 `with zipfile.ZipFile(mission.file_path, "r") as zip_read`.
```

**Fix.** Document that folder-sourced DcsMission objects are read-only, or guard write_miz to reject a directory file_path with a clear error instead of failing opaquely inside ZipFile.

### Python · Spawn-data validation

#### VMR-055 — Malformed per-mission spawn YAML raises unguarded KeyError/ValueError in the Lua renderer
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort medium · roles: developer, mission-maker  
`src/python/veaf-tools/spawn_data_injector/spawn_data_emitter.py:105`  

**Issue.** The renderer indexes required keys directly on entries that originate (after merge_spawn_data) from an unvalidated per-mission YAML file: entry['aliases'] and entry['unitType'] (line 105), entry['aliases']/entry['disposition']/entry['units'] (lines 111-118), unit['type'] (line 91), and int(value['min'])/int(value['max']) (line 84). A mission-data entry missing any of these keys (or with a non-numeric disposition/number) raises a raw KeyError/ValueError/TypeError with no context instead of an actionable validation error. There is no schema validation on mission_data_file before it is merged and rendered.  

**Evidence.**
```
line 84: rendered = f"{{ min = {int(value['min'])}, max = {int(value['max'])} }}"
line 105: f"...aliases = {_lua_aliases(entry['aliases'])}, unitType = {_lua_string(entry['unitType'])} }},"
line 116: f"      disposition = {{ h = {int(disp['h'])}, w = {int(disp['w'])} }},"  — all direct [] access on merged mission data.
```

**Fix.** Validate the merged spawn-data structure (required keys/types per entry) before rendering, or wrap rendering in a try/except that surfaces the offending entry via logger.error with the alias/index, so a mission-maker gets a clear message instead of a stack trace.

> _Verifier:_ The code matches the claim exactly. In spawn_data_injector_worker.py:156, work() does yaml.safe_load on the user-authored per-mission file (src/spawn-groups.yaml, wired in build.py:383-391) with no schema validation. merge_spawn_data (line 44-72) only reads entry['aliases'] and passes entries verbatim. render_spawn_data_lua then does unguarded direct indexing: entry['aliases']/entry['unitType'] (line 105), entry['aliases']/entry['disposition']/entry['units'] (lines 111,115,118), unit['type'] (li

### Python · Airwave zone generation

#### VMR-058 — respawn_default_offset indexed as a 2-element list with no validation
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/veaf_libs/lua_config_generator.py:676`  

**Issue.** _emit_airwave_zone reads respawn_default_offset from YAML and immediately subscripts ro[0] and ro[1]. YAML values are attacker/author-controlled: if the author writes a scalar (respawn_default_offset: 5), a single-element list, or a mapping, this raises TypeError/IndexError/KeyError and aborts the whole build with an unhelpful traceback instead of a validation error. The surrounding code otherwise defensively coerces (`or []`, `.get(...)`), so this stands out as an unguarded assumption.  

**Evidence.**
```
if ro := zone.get("respawn_default_offset"):
    lines.append(f"{indent}    :setRespawnDefaultOffset({ro[0]}, {ro[1]})")
```

**Fix.** Validate that ro is a list/tuple of length 2 before indexing (e.g. `if isinstance(ro, (list, tuple)) and len(ro) == 2:`), and otherwise log a localized warning via veaf_libs.logger and skip the setter — matching how the module reports other malformed config rather than crashing.

> _Verifier:_ At lua_config_generator.py:675-676 the guard `if ro := zone.get("respawn_default_offset"):` only tests truthiness, then line 676 unconditionally subscripts `ro[0]` and `ro[1]`. I confirmed no validation of this field's shape exists anywhere in the pipeline: yaml_validator.py (178 lines) only validates module-level keys (enabled/logLevel/settings types) and never inspects airwave zone inner fields; the only other reference to `respawn_default_offset` outside this file is config_migrator.py:1652 w

### Python · Qra generation

#### VMR-059 — QRA silence_all guard is a dead branch — always true
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/veaf_libs/lua_config_generator.py:483`  

**Issue.** silence_all is read with a default of False (line 483) and then guarded by `if silence_all is not None:` (line 484). Because the default is False (never None), the condition is always true, so ToggleAllSilence(false) is unconditionally emitted even when the author never set silence_all. The intent was clearly to emit the call only when the key was present. The guard is thus dead/incorrect and produces noise in the generated Lua (and a redundant runtime call).  

**Evidence.**
```
silence_all = qra_section.get("silence_all", False)
if silence_all is not None:
    lines.append(f"    VeafQRA.ToggleAllSilence({'true' if silence_all else 'false'})")
```

**Fix.** Use `if "silence_all" in qra_section:` (default None and test for None), so ToggleAllSilence is only emitted when the author explicitly set the flag.

### Python · Named points generation

#### VMR-060 — NAMEDPOINTS lat/lon passed to coord.LLtoLO as strings and interpolated unescaped
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/veaf_libs/lua_config_generator.py:456`  

**Issue.** Custom-point lat/lon are emitted as quoted Lua strings (coord.LLtoLO("{lat}", "{lon}")) with defaults of the string "0". DCS's coord.LLtoLO expects numeric degrees, so passing quoted strings relies on implicit Lua string→number coercion and will error at runtime if the value cannot coerce; the point name is likewise interpolated with no escaping (a name containing a double-quote breaks the table). This is both a type-correctness issue and another instance of the unescaped-string problem.  

**Evidence.**
```
lines.append(f'        {{name = "{pt_name}", point = coord.LLtoLO("{lat}", "{lon}")}},')
```

**Fix.** Emit lat/lon as numeric Lua literals via _to_lua_scalar (after coercing to float) rather than quoted strings, and emit pt_name via _emit_lua_string.

### Python · Module scanning

#### VMR-061 — get_modules() loads bundled/pre-generated JSON with no schema validation, trusting it into Lua emission
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/veaf_libs/lua_module_scanner.py:112`  

**Issue.** get_modules() returns json.loads(...) directly for the bundled and pre-generated cases with no validation that entries are dicts carrying id/var_name/filename. _build_id_to_var (lua_config_generator.py:426) then indexes mod['id'] and mod['var_name']; a malformed or truncated JSON (partial build artifact) yields a KeyError/TypeError deep in generation rather than a clear 'module list corrupt' error. Given this list drives which Lua globals get initialize() calls emitted, a silently-wrong list also produces a subtly broken config.  

**Evidence.**
```
path = _bundled_json_path()
if path:
    return json.loads(path.read_text(encoding="utf-8"))
```

**Fix.** Validate the decoded list minimally (each item is a dict with the required keys) and raise/log a clear localized error if not, instead of letting a downstream KeyError surface.

### Python · Mission validation

#### VMR-062 — Source-mission parse swallows all exceptions, silently disabling reference checks
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/veaf_libs/mission_validator.py:194`  

**Issue.** _read_source_mission catches bare Exception and returns None on any failure, which in validate_mission_folder is treated identically to 'source mission absent' — the group/zone/unit reference checks (4-6) are silently skipped and only a generic 'no source mission' warning is shown. A corrupt or partially-parseable mission table therefore passes validation with a green-ish result, defeating the purpose of the pre-build validate command. The author gets no signal that the very checks they ran validate for were disabled by a parse error rather than a missing file.  

**Evidence.**
```
except Exception:  # noqa: BLE001 - a parse failure just disables the mission-content checks
    return None
return content if isinstance(content, dict) else None
```

**Fix.** Distinguish 'file absent' (skip quietly) from 'file present but failed to parse' (emit a distinct WARNING/ERROR naming the parse failure), so a corrupt mission table is surfaced instead of masquerading as 'no source mission'.

### Python · Update check

#### VMR-063 — Unparseable current version yields a spurious 'update available' prompt
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/python/veaf-tools/veaf_libs/update_checker.py:37`  

**Issue.** _version_tuple returns (0,) whenever the version string contains a non-integer segment. If the running build's version cannot be parsed (e.g. a dev/'unknown' or dirty version), current becomes (0,) and any real latest tag compares greater, so the tool nags the user to update on every interactive run even when already current. The two operands are also parsed with different rules only via the same helper, so a latest tag like '6.10' vs current '6.9' compares correctly, but the (0,) fallback silently poisons the comparison.  

**Evidence.**
```
try:
    return tuple(int(x) for x in v.split("."))
except ValueError:
    return (0,)
```

**Fix.** On parse failure, skip the comparison (return None and short-circuit the caller) rather than substituting (0,), so an unparseable local version never produces a false 'newer available' result.

### Python · Chatbot repl

#### VMR-064 — ask REPL only catches RuntimeError, so any other worker error crashes the session
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: pilot, mission-maker  
`src/python/veaf-tools/veaf_tools/commands/ask.py:85`  

**Issue.** Both the one-shot path and the interactive REPL wrap `_answer` in `except RuntimeError`. WorkerChatWorker.ask streams over the network; a transient error surfaced as anything other than RuntimeError (ConnectionError, TimeoutError, a provider-SDK exception, JSON/decoding error, etc.) is not caught. In the REPL this tears down the whole interactive session on a single transient failure instead of printing the error and continuing to the next prompt.  

**Evidence.**
```
try:
            _answer(line)
        except RuntimeError as exc:
            console.print(str(exc), style="red")
```

**Fix.** Catch a broader but still non-fatal set (e.g. `except Exception as exc:` while excluding KeyboardInterrupt/typer.Exit) in the REPL loop so a single failed turn is reported and the loop continues.

#### VMR-116 — ask history cap constant is named 'turns' but counts messages
⚪ **LOW** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/veaf_tools/commands/ask.py:62`  

**Issue.** _MAX_KEPT_TURNS is documented as capping 'turns', but each turn appends two entries (user + assistant), so `del history[:-_MAX_KEPT_TURNS]` actually retains only the last 24 messages = 12 turns. The behavior is safe (empty slice when short), but the name/semantics mismatch is misleading for anyone tuning the value.  

**Evidence.**
```
_MAX_KEPT_TURNS = 24
    ...
        # Cap the in-memory history in long REPL sessions (the Worker only sends the tail anyway).
        del history[:-_MAX_KEPT_TURNS]
```

**Fix.** Either rename to _MAX_KEPT_MESSAGES, or trim by turns (`del history[:-2 * _MAX_KEPT_TURNS]`) so the constant matches its name.

### Python · Process exit

#### VMR-065 — Commands rely on the site-provided exit() builtin instead of typer.Exit
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/veaf_tools/commands/build.py:239`  

**Issue.** Several commands terminate with the bare builtin `exit()` / `exit(1)` (build.py:239, extract.py:42, waypoints.py:60/129, weather.py, aircraft_groups.py:67, inject_presets.py:45, prepare.py:162/247). `exit`/`quit` are injected by the `site` module and are documented as intended for interactive use only; they are absent when Python is started with `-S` and are unreliable in some frozen/PyInstaller configurations — exactly the packaged-exe scenario this tool targets. If `exit` is missing this raises NameError instead of exiting cleanly. The rest of the codebase already uses `raise typer.Exit(...)` (e.g. user_config.py:44/58, validate.py:34/60), so this is an inconsistency as well.  

**Evidence.**
```
if readme:
        if typer.confirm(t("help.confirm_doc")):
            md_render = Markdown(MissionBuilderREADME)
            console.print(md_render)
        exit()
```

**Fix.** Replace bare `exit()` / `exit(1)` with `raise typer.Exit()` / `raise typer.Exit(code=1)` (or `sys.exit`) consistently across these command modules.

### Python · Mission file lookup

#### VMR-066 — Mission lookup by name uses raw glob, treating name metacharacters as patterns
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort medium · roles: mission-maker  
`src/python/veaf-tools/veaf_tools/commands/extract.py:53`  

**Issue.** The bare-name resolution `p_mission_folder.glob(f"{mission_name_or_file}*.miz")` (duplicated in aircraft_groups.py:108, waypoints.py:87/140, inject_presets.py:51) interpolates the user-supplied name directly into a glob pattern. A name containing glob metacharacters ([, ], ?, *) is interpreted as a pattern rather than a literal prefix, so it can silently match the wrong file or nothing. This exact logic is already centralized in veaf_libs.paths.resolve_mission_file, which the commands do not use — so the pattern is both duplicated and slightly wrong.  

**Evidence.**
```
if not mission_name_or_file.lower().endswith(".miz"):
        if files := list(p_mission_folder.glob(f"{mission_name_or_file}*.miz")):
            p_input_mission = max(files, key=lambda f: f.stat().st_mtime)
```

**Fix.** Route these call sites through resolve_mission_file() (or glob.escape the name before interpolation) to fix the metacharacter handling and remove the copy-pasted resolution logic.

### Python · Waypoint extraction

#### VMR-067 — extract_from_mission crashes with TypeError on a group that has no 'name'
⚪ **LOW** · Error / bug · verdict **PLAUSIBLE** · effort small · roles: developer, mission-maker  
`src/python/veaf-tools/waypoints_injector/waypoints_injector_worker.py:302`  

**Issue.** group_name is read with group.get("name"), which returns None when a group has no name key (valid/possible in a raw .miz). group_name_pattern is never None (default pattern '.*' is compiled in __init__), so self.group_name_pattern.match(group_name) is called with None, and re.Pattern.match(None) raises TypeError: expected string or bytes-like object. A single nameless aircraft group in the input .miz aborts the whole waypoint extraction.  

**Evidence.**
```
line 299: group_name = group.get("name")
line 302: if self.group_name_pattern and not self.group_name_pattern.match(group_name):  — group_name can be None here.
```

**Fix.** Guard the name: e.g. `group_name = group.get("name") or ""`, or `if group_name is None: continue`, before calling .match(). (Note the aircraft extractor already defends with group.get("name", "").)

### Python · Github publishing

#### VMR-104 — GitHub publish can leave a dangling tag with no release when gh CLI is absent
⚪ **LOW** · Error / bug · verdict **PLAUSIBLE** · effort medium · roles: developer, server-admin  
`veaf_build/github.py:57`  

**Issue.** publish() first runs _publish_with_git_tags (which force-pushes published-v<version> and published-latest to origin) and only afterwards runs _publish_with_gh_cli. If the gh CLI is not installed, _publish_with_gh_cli logs a warning and returns without creating any release or uploading assets. The result is a pushed remote tag (and a moved published-latest) that points at a release/asset that never got created — the updater's clients resolving published-latest can then fetch a tag with no published.zip attached, i.e. a broken 'latest'. The tag push should be gated on the release actually being creatable, or ordered after asset upload.  

**Evidence.**
```
if not self.skip_git_tags:
    self._publish_with_git_tags(package_path)
if self.token:
    self._publish_with_gh_cli(package_path, package_hash, force=force)
```

**Fix.** Verify gh availability and create the release (with assets) before force-moving published-latest; on gh failure, do not move/publish the latest tag. Alternatively push tags only after _publish_with_gh_cli succeeds.

#### VMR-105 — Force-pushed git tags with swallowed local failures in tag publishing
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort medium · roles: developer, server-admin  
`veaf_build/github.py:79`  

**Issue.** The versioned and published-latest tags are pushed with 'git push origin -f', force-overwriting whatever the remote tag pointed at. Combined with the always-run local 'git tag -d' before each create, this makes the operation destructive and non-idempotent under concurrency (two publishers, or a manual tag) with no confirmation. Errors from the local 'git tag -d' are silently discarded (capture_output, no check), which is intended, but a leftover tag from a partially-failed prior run plus a force push means published-latest can be moved even when the corresponding release upload later fails.  

**Evidence.**
```
subprocess.run(
    ["git", "push", "origin", "-f", latest_tag_name],
    cwd=str(self.script_root),
    capture_output=True,
    check=True,
)
```

**Fix.** Only move published-latest after the release + assets for the versioned tag are confirmed uploaded; consider dropping unconditional -f or guarding it behind the force flag.

### Python · Preset matching

#### VMR-106 — Unit-type preset lookup compiles mission-maker regex on every aircraft match
⚪ **LOW** · Optimization · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/python/veaf-tools/presets_injector/presets_manager.py:482`  

**Issue.** `_match_unit_type` calls `re.fullmatch(key, unit_type)` for every assignment key on every lookup, recompiling each pattern each time. For missions with many unit types and many assignment keys this is repeated O(keys) recompilation per unit. The keys are mission-maker-controlled regexes, so a pathological pattern could also be slow to match (ReDoS-ish), though the design-time context limits the blast radius.  

**Evidence.**
```
try:
                if re.fullmatch(key, unit_type):
                    return assignment
            except re.error:
                pass
```

**Fix.** Pre-compile the regex keys once (e.g. cache compiled patterns keyed by string) when the assignment collection is built, and reuse them in the hot lookup path.

### Python · Spawn-data merge

#### VMR-107 — merge_spawn_data recomputes framework alias sets on every mission entry (O(n*m))
⚪ **LOW** · Optimization · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/spawn_data_injector/spawn_data_injector_worker.py:66`  

**Issue.** For each mission entry, the inner loop rebuilds the lowercased alias set of every existing framework entry from scratch: `{str(a).lower() for a in existing.get('aliases') or []}`. This is O(n*m) over alias strings. Datasets are currently small so impact is negligible, but the framework alias sets could be precomputed once per kind.  

**Evidence.**
```
line 66: if aliases & {str(a).lower() for a in existing.get("aliases") or []}:  — set rebuilt inside the per-mission-entry loop.
```

**Fix.** Precompute a list of (entry, lowercased_alias_set) for merged[kind] once before the mission loop, updating it as entries are appended, and test membership against the cached sets.

### Python · Mission.yaml i/o

#### VMR-108 — build reads and parses mission.yaml multiple times per invocation
⚪ **LOW** · Optimization · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/python/veaf-tools/veaf_tools/commands/build.py:421`  

**Issue.** mission.yaml is opened and yaml.safe_load-parsed at least twice: once inside _resolve_output_mission (line 67-71, which also runs validate_yaml_file) and again at line 421-424 for the build-variant peek. The second read uses plain safe_load with no validation, so the two call sites are also inconsistent about validation. Parsing the same file twice is redundant work and a minor divergence risk if the reads disagree.  

**Evidence.**
```
peek_yaml: dict = {}
    if mission_yaml_path.exists():
        with mission_yaml_path.open("r", encoding="utf-8") as fh:
            peek_yaml = yaml.safe_load(fh) or {}
    plan = _build_plan(peek_yaml, profile, p_output_mission, mission_base_name)
```

**Fix.** Load and validate mission.yaml once near the top of build() and pass the parsed mapping into both _resolve_output_mission and _build_plan.

### Python · Release package

#### VMR-112 — Dead code: release packager still tries to add removed debug/trace Lua variants
⚪ **LOW** · Refactoring · verdict **UNVERIFIED** · effort small · roles: developer  
`veaf_build/worker.py:686`  

**Issue.** create_release_package loops over veaf-scripts-debug.lua / veaf-scripts-trace.lua, but _copy_lua_files_to_published (line 383) documents 'variants removed in favour of runtime log level' and build_lua_scripts only ever produces the single veaf-scripts.lua. These variant files are never generated, so the loop is dead code that survives only as confusing noise and a false suggestion that variants still ship.  

**Evidence.**
```
# Add debug and trace variants
for variant_name in ["veaf-scripts-debug.lua", "veaf-scripts-trace.lua"]:
    variant_path = self.build_dir / variant_name
    if variant_path.exists():
```

**Fix.** Delete the debug/trace variant loop; it can never match a produced artifact.

### Python · Type hints

#### VMR-113 — Public helper classes/methods missing -> None return annotations
⚪ **LOW** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py:83`  

**Issue.** Project rules mandate explicit return-type annotations on all functions. Several methods here lack them: ValidationError.__init__ (line 83), InjectionResult.__post_init__ (line 123), and AircraftGroupsInjectorWorker.__init__ (line 497). The instance attributes on ValidationError (self.level/path/message/details) are also untyped. mypy strict / the quality ratchet will flag these.  

**Evidence.**
```
line 83: def __init__(self, level: str, path: str, message: str, details: str | None = None):  — no `-> None`; line 123: def __post_init__(self):  — no `-> None`.
```

**Fix.** Add `-> None` to these __init__/__post_init__ definitions (and annotate the ValidationError attributes) to satisfy the mandatory-annotation rule and the mypy ratchet.

#### VMR-114 — collect_files_from_globs uses untyped logger param and swallows non-existent folders silently
⚪ **LOW** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/mission_tools/mission_constants.py:139`  

**Issue.** collect_files_from_globs declares `logger=None` with no type annotation, violating the project's mandatory-annotation rule, and shadows the module-level convention of using veaf_libs.logger by accepting an arbitrary logger object. Public functions in this file are otherwise annotated; this one is the outlier and the nested helpers reference the free variable `dest_location` defined in the outer loop (line 202), which is a readability hazard (helper _add_file_to_results depends on loop state it does not receive as a parameter).  

**Evidence.**
```
L139-141 `def collect_files_from_globs(base_folder: Path, file_patterns: list[tuple[str, str]], alternative_folder: Path | None = None, logger=None) -> dict[str, bytes]:`; L159 `key = (dest_location / relative_path / file_path.name).as_posix()` references outer-scope `dest_location` set at L202.
```

**Fix.** Annotate the parameter (e.g. `logger: LoggerType | None = None`) or drop it in favor of the module logger, and pass dest_location explicitly into _add_file_to_results instead of closing over loop state.

### Python · Logging policy

#### VMR-115 — Migration script uses print() throughout, violating the mandatory logger rule
⚪ **LOW** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/veaf_libs/migrate_lazy_log.py:128`  

**Issue.** CLAUDE.md states an absolute prohibition on the native print() function; only veaf_libs.logger may be used. This module (under veaf_libs/) uses print() for all of its output (lines 128, 132, 141, 145, 148-156). Even as a one-shot maintenance script it lives in the library package and violates the project's own zero-tolerance logging rule; it will also be flagged by any print-lint the team adds.  

**Evidence.**
```
print(f"ERROR: cannot find src/scripts/veaf (tried {lua_dir})", file=sys.stderr)
...
print(f"Scanning {len(lua_files)} Lua files in {lua_dir} ...")
```

**Fix.** Replace print() calls with veaf_libs.logger.logger (info/error), or if truly a standalone CLI kept out of the library, move it under a scripts/ tools directory and document the exemption.

### Python · Logging convention

#### VMR-118 — radio_specs_updater.py uses print() throughout instead of the veaf_libs logger
⚪ **LOW** · Readability · verdict **UNVERIFIED** · effort medium · roles: developer  
`veaf_build/radio_specs_updater.py:46`  

**Issue.** This module emits all its progress/status via bare print() (clone progress, per-file parse status, error lines, output paths), whereas the rest of veaf_build (cli.py, worker.py, github.py) consistently uses veaf_libs.logger / rich console. The project rule mandates veaf_libs.logger and prohibits print(). Because it is invoked from cli.py's update-dcs-data command (a first-class CLI path), the inconsistent, uncoloured, unfiltered output leaks straight to stdout and bypasses the shared logger's verbosity control.  

**Evidence.**
```
print(f"Cloning dcs-lua-datamine@{ref} into {dest}...")
...
print(f"ERROR: {e}", file=sys.stderr)
```

**Fix.** Replace print()/sys.stderr writes with logger.info/logger.debug/logger.warning from veaf_libs.logger, matching the rest of veaf_build.

### Python · Lua deserialization

#### VMR-128 — luadata read() silently ignores its multival argument
🔵 **INFO** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/luadata/io/read.py:25`  

**Issue.** read(path, encoding, multival=False) accepts multival but hardcodes multival=False in the delegated unserialize() call, so a caller requesting multiple top-level values (e.g. `return 1, 2`) silently gets only the first. This is a latent correctness bug in the (vendored) helper; harmless today because the .miz parsing path calls unserialize() directly, not read(), but the parameter is a trap for future callers.  

**Evidence.**
```
return unserialize(text, encoding=encoding, multival=False)
```

**Fix.** Forward the argument: `unserialize(text, encoding=encoding, multival=multival)`.

### Python · Config loading

#### VMR-131 — config_file_path() re-scans the filesystem on every user_config.get()
🔵 **INFO** · Optimization · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/veaf_libs/user_config.py:89`  

**Issue.** _load() caches the parsed config in _cache, but every call still first computes config_file_path() -> _find_config_file(), which does up to two Path.exists() stat calls plus an import of veaf_home. Because _load() returns early on cache hit only AFTER... actually it returns before calling config_file_path() on a cache hit, so the hot path is fine; however get() -> _load() is cheap only because of that early return. The redundancy is limited to the first miss. Low value: the caching is correct. Flagging only that _find_config_file re-imports veaf_home each miss.  

**Evidence.**
```
def _load() -> dict[str, Any]:
    global _cache
    if _cache is not None:
        return _cache
    path = config_file_path()
    _cache = _parse_yaml_file(path) if path is not None else {}
    return _cache
```

**Fix.** No action required for correctness; if desired, memoize the resolved path alongside _cache. Included for completeness only.

### Python · Prerequisite validation

#### VMR-134 — check_command ignores its display_name argument
🔵 **INFO** · Refactoring · verdict **UNVERIFIED** · effort small · roles: developer  
`veaf_build/worker.py:180`  

**Issue.** check_command(self, command, display_name) never uses display_name — it only runs `command --version`. The parameter is dead; callers pass a human name that is silently ignored, which is misleading (a reader assumes the failure message uses it, but the message is built in validate_prerequisites from the dict values instead).  

**Evidence.**
```
def check_command(self, command: str, display_name: str) -> bool:
    """Check if a command is available."""
    try:
        result = subprocess.run(
            [command, "--version"],
```

**Fix.** Drop the unused display_name parameter (and update the one caller), or use it in a debug/error message.

### Python · Units reference doc

#### VMR-135 — _read_db_version truncates the source ref to 8 chars, risking a misleading version label
🔵 **INFO** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/python/veaf-tools/veaf_libs/dcs_units_parser.py:116`  

**Issue.** The datamine provenance ref is truncated to its first 8 characters (m.group(1)[:8]) and prefixed 'datamine-'. This assumes the ref is a git SHA; if the header instead carries a date, tag, or URL, the truncation silently mislabels the generated reference doc's provenance. Low impact (a doc header only) but the assumption is undocumented and easy to trip.  

**Evidence.**
```
return f"datamine-{m.group(1)[:8]}"
```

**Fix.** Either document that the ref is expected to be a git SHA, or only truncate when the captured value matches a hex-SHA pattern; otherwise emit it verbatim.


---

## 🌙 Lua — 62 findings

### Lua · Chat command injection

#### VMR-001 — Lua injection: unescaped player name/command interpolated into executed mission code
🔴 **CRITICAL** · Security flaw · verdict **CONFIRMED** · effort medium · roles: server-admin, pilot  
`src/scripts/Hooks/VEAF-Server-hook.lua:473`  

**Issue.** In veafServerHook.parse, playerName, unitName, _module and _command are inserted with string.format into RUN_COMMAND ('veafRemote.executeCommandFromRemote("%s", "%s", "%s", "%s", "%s")') and the result is executed verbatim by injectCode() via net.dostring_in('mission', 'a_do_script([===[' .. payload .. ']===]')'). None of the fields are escaped. A player only needs level>=1 (the catch-all branch) and can break out of the Lua string literal — e.g. a chat command whose payload contains '") <arbitrary lua> --' — to run arbitrary Lua in the mission scripting environment. Worse, playerName is fully attacker-controlled and is injected in the onPlayerConnect path (REGISTER_PLAYER, line 216) BEFORE any level check, so a malicious display name like '","0","x") <lua> --' yields remote code execution against every mission at connect time. This is a full sandbox breakout of the marker/chat gate.  

**Evidence.**
```
local payload = string.format(RUN_COMMAND, tostring(playerName), tostring(pilot.level), tostring(unitName), tostring(_module), tostring(_command))
```

**Fix.** Never build Lua source by concatenating untrusted strings. Escape every interpolated value (e.g. %q or a serializer that produces safe Lua literals), or better, pass the values as data through a pre-registered function call rather than generated source. At minimum apply string.format('%q', value) to playerName, unitName, _module and _command before embedding, and do the same in REGISTER_PLAYER/REGISTER_PLAYER_SLOT/SEND_MESSAGE.

> _Verifier:_ I read src/scripts/Hooks/VEAF-Server-hook.lua in full. The injection mechanism is exactly as claimed. injectCode() (line 512-522) builds `'return a_do_script(' .. '[===[' .. payload .. ']===]' .. ')'` and runs it via net.dostring_in('mission', ...), so the payload is compiled and executed as Lua in the mission scripting environment. The payload is produced by string.format into templates that wrap each field in ordinary double-quoted Lua string literals — RUN_COMMAND = `... executeCommandFromRem

#### VMR-002 — Injection via playerName in REGISTER_PLAYER / REGISTER_PLAYER_SLOT before authentication
🔴 **CRITICAL** · Security flaw · verdict **CONFIRMED** · effort small · roles: server-admin, pilot  
`src/scripts/Hooks/VEAF-Server-hook.lua:216`  

**Issue.** onPlayerConnect and onPlayerChangeSlot build REGISTER_PLAYER/REGISTER_PLAYER_SLOT with the raw player-chosen name and inject them via injectCode() unconditionally, with no level or password check. Because playerName is placed inside a Lua string literal in code that is then executed by a_do_script, any player can achieve arbitrary mission-environment code execution just by connecting with a crafted name — no VEAF pilot level required. This is the pre-auth variant of the injection and is the most exploitable entry point.  

**Evidence.**
```
local payload = string.format(REGISTER_PLAYER, playerName, pilot.level, ucid)
    veafServerHook.logTrace(string.format("payload=%s",veafServerHook.p(payload)))
    veafServerHook.injectCode(payload)
```

**Fix.** Escape playerName (and ucid) with %q before formatting into REGISTER_PLAYER/REGISTER_PLAYER_SLOT, or pass them as validated data. Reject/sanitize names containing quotes/newlines/closing long-bracket sequences.

> _Verifier:_ Verified in src/scripts/Hooks/VEAF-Server-hook.lua. REGISTER_PLAYER (line 65) is `[[ ... veafRemote.registerUser("%s", "%s", "%s") ... ]]`, so playerName fills a double-quoted Lua string literal. onPlayerConnect (200-218) reads playerName from net.get_player_info(id).name (fully attacker-controlled) and, unconditionally, builds `string.format(REGISTER_PLAYER, playerName, pilot.level, ucid)` (line 216) and calls injectCode (line 218). Lines 216/218 are OUTSIDE the if/else: an unknown pilot just g

### Lua · Marker command auth gate

#### VMR-003 — veafGroundAI marker commands run with no security check
🟠 **HIGH** · Security flaw · verdict **CONFIRMED** · effort small · roles: server-admin, pilot, mission-maker  
`src/scripts/veaf/veafGroundAI.lua:599`  

**Issue.** veafGroundAI.executeCommand() (registered as a marker command handler and reachable from any player-typed '_ground ...' map marker) never calls veafSecurity.checkSecurity_* nor honors the bypassSecurity flag. The SET/ORDER verbs let any player bind an ArtilleryUnitHandler to an arbitrary named DCS group (or the nearest allied group within 250m) and push a real FireAtPoint task at attacker-chosen coordinates. Every other marker-command module in the cluster (veafCasMission uses checkSecurity_L9, veafTransportMission uses checkSecurity_L1) gates its destructive actions; GroundAI does not. On a multiplayer server this is an unauthenticated way to commandeer friendly artillery and shell arbitrary map coordinates.  

**Evidence.**
```
function veafGroundAI.executeCommand(eventPos, eventText, eventCoalition, markId, bypassSecurity, spawnedGroups, route)
  ... (no veafSecurity call anywhere; bypassSecurity param is ignored) ...
  if options.verb == veafGroundAI.VERB_SET then ... handler:setDcsGroup(group); handler:start() ... 
  elseif options.verb == veafGroundAI.VERB_ORDER then ... handler:orderTextAnalysis(options.order) -> self:fireForEffect(...)
```

**Fix.** Gate the destructive verbs (SET/UNSET/ORDER/START/STOP/CLEAR) behind veafSecurity (e.g. checkSecurity_L1 or L9 with markId), honoring bypassSecurity for the trusted interpreter path exactly as veafCasMission.executeCommand does.

> _Verifier:_ Verified in src/scripts/veaf/veafGroundAI.lua and veafCommands.lua. The central dispatcher veafCommands.dispatchMarker (veafCommands.lua:82-90) calls every registered handler with bypassSecurity=false, fromMarker=true and does NO security check itself — each module must gate its own destructive actions. GroundAI's registered handler (veafGroundAI.lua:813-818) only checks fromMarker, then calls onEventMarkChange, which calls executeCommand with just 4 args, so the bypassSecurity param is never ev

### Lua · Srs radio / os.execute

#### VMR-004 — Unauthenticated OS command injection via SRS transmit/play marker commands
🟠 **HIGH** · Security flaw · verdict **CONFIRMED** · effort medium · roles: server-admin, pilot, mission-maker  
`src/scripts/veaf/veafRadio.lua:755`  

**Issue.** veafRadio._transmitViaSRS builds a Windows shell command with string.format and passes it to os.execute(). The interpolated values message, file (path), name, frequencies and modulations all originate from player-typed map-marker text (veafRadio.markTextAnalysis extracts 'message', 'path', 'name', 'freq', 'mod' keywords) and are never sanitized. message/file/name are wrapped only in double quotes, and frequencies/modulations are injected completely unquoted. A player can place a marker such as '_radio transmit, message " & calc & "' (or use freqs/mods with shell metacharacters) to break out of the quoting and execute arbitrary commands in the DCS server host process. Critically, veafRadio.executeCommand performs NO security check for the transmit/play branch and is registered as an unconditional command handler (PRIORITY_RADIO), and the '-send'/'-play' shortcuts reach it — so this is reachable by any unauthenticated player in multiplayer, not just an authenticated mission master.  

**Evidence.**
```
local cmd = string.format(
  'start /min "%s" "%s\\%s" %s -f %s -m %s -c %s -p %s -n "%s" %s',
  STTS.DIRECTORY, STTS.DIRECTORY, STTS.EXECUTABLE, contentOption,
  frequencies, modulations, coalition, STTS.SRS_PORT, name, posOption)
...
local result = l_os.execute(cmd)
```

**Fix.** Do not build a shell string from player input. Validate frequencies/modulations against a strict numeric/enum whitelist, reject or escape any character outside [A-Za-z0-9 .,_-] in message/name/path, and gate the transmit/play commands behind veafSecurity.isAuthenticated() (or bypassSecurity) the same way secured radio menu items are. Prefer passing arguments without a shell (avoid os.execute with 'start /min ...') where possible.

> _Verifier:_ I read veafRadio.lua, veafCommands.lua and veaf.lua and the full chain holds. _transmitViaSRS (line 755) formats a Windows shell string and runs l_os.execute(cmd) (line 769). message/file go into `-t "%s"` / `-i "%s"` (lines 741,743), name into `-n "%s"`, while frequencies and modulations are injected COMPLETELY UNQUOTED as `-f %s -m %s` (lines 761-762). All five come from markTextAnalysis (lines 211-238) which extracts them from raw marker text via veaf.split/veaf.breakString/veaf.trim (veaf.lu

### Lua · Remote code execution

#### VMR-013 — dcs-fiddle-server executes arbitrary Lua from unauthenticated HTTP requests
🟡 **MEDIUM** · Security flaw · verdict **PLAUSIBLE** · effort medium · roles: server-admin  
`src/scripts/other/dcs-fiddle-server.lua:270`  

**Issue.** handle_request base64-decodes the request path and runs it with loadstring()() (or net.dostring_in for non-default env) with no authentication, token, or origin check, and responds with Access-Control-Allow-Origin '*'. Anyone able to reach 127.0.0.1:12080/12081 (including any local process, or a browser via DNS-rebinding given the wildcard CORS) obtains full arbitrary code execution in the DCS mission and Hooks environments. If this script is ever shipped/injected on a production server it is a complete host compromise. Even localhost-only, the wildcard CORS plus GET-based command channel makes it reachable from a victim's browser.  

**Evidence.**
```
local loaded = assert(loadstring(luastring))
        __info("[handle_request] - Executing LUA String...")
        local result = loaded()
```

**Fix.** This is a developer/debug tool and must never be present on a live server. Gate it behind an explicit non-default opt-in, bind only to loopback, require a per-session secret token, and set a strict (non-wildcard) CORS/Origin allowlist. Document loudly that it de-sanitizes the environment and grants RCE.

### Lua · Match manager events

#### VMR-017 — onEvent aborts all remaining match managers on a coalition mismatch
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, server-admin  
`src/scripts/other/DcssbMatchManager.lua:417`  

**Issue.** In the S_EVENT_PLAYER_ENTER_UNIT loop over all match managers, when the entering unit's coalition does not match a manager's configured coalition, the code does `return`, which exits the entire onEvent handler rather than `continue`-ing to the next manager. With multiple match managers of differing coalitions, the first manager whose coalition does not match a given player silently prevents every subsequent manager from ever registering that player. The same premature `return` appears in the trigger-zone branch (line 427), so a manager with a trigger zone blocks all managers after it in the list from acting on the same event.  

**Evidence.**
```
if unit:getCoalition() ~= matchManager:getCoalition() then
    return
end
```

**Fix.** Replace both `return`s inside the per-manager loop with a skip to the next iteration (e.g. wrap the per-manager body in a function and `return`/`goto continue`, or restructure so only the current manager is skipped), so each manager is evaluated independently.

> _Verifier:_ In src/scripts/other/DcssbMatchManager.lua the S_EVENT_PLAYER_ENTER_UNIT handler loops `for _, matchManager in pairs(DcssbMatchManager.matchManagers) do` (line 411). Lua has no loop-local `return`, so both `return` statements — line 418 (coalition mismatch) and line 427 (trigger-zone branch) — exit the entire onEvent function, aborting the loop over the remaining managers. `DcssbMatchManager.matchManagers` genuinely holds multiple managers: addMatchManager appends to it (line 302) and addMatchMa

### Lua · Carrier tanker route

#### VMR-018 — continueCarrierOperations dereferences carrier.tankerData without nil check
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafCarrierOperations.lua:647`  

**Issue.** The tanker branch is entered whenever veaf.mist.getGroupData(carrier.tankerUnitName) is truthy, but the route it builds reads carrier.tankerData.tankerTacanTask (line 584) and carrier.tankerData.tankerFrequency (line 647). carrier.tankerData is populated by veaf.getTankerData, which returns nil when veaf.getGroupData returns nil, and even when non-nil it only sets tankerFrequency/tankerTacanTask conditionally. If a tanker group exists but tankerData is nil (guards use two different data sources) or lacks a frequency, 'carrier.tankerData.tankerFrequency * 1000000' throws (arithmetic on nil / index into nil), aborting the carrier operations step and leaving the carrier mid-manoeuvre.  

**Evidence.**
```
frequency = carrier.tankerData.tankerFrequency * 1000000, --Hz
... and earlier ...
[2] = carrier.tankerData.tankerTacanTask,
```

**Fix.** Guard the tanker route setup with 'if carrier.tankerData and carrier.tankerData.tankerFrequency then', and use the same data source for the entry guard and for populating tankerData so they cannot disagree.

> _Verifier:_ Verified in src/scripts/veaf/veafCarrierOperations.lua. The tanker branch in continueCarrierOperations is entered when the guard at line 488, `if not veaf.mist.getGroupData(carrier.tankerUnitName)`, is truthy. veaf.mist.getGroupData (veaf.lua:155) reads mist.DBs.groupsByName, a DIFFERENT data source than the one that populates carrier.tankerData: at line 973 carrier.tankerData = veaf.getTankerData(...), which calls veaf.getGroupData (veaf.lua:2198, iterating env.mission.coalition). veaf.getTanke

### Lua · Marker text analysis

#### VMR-019 — tonumber(nil) comparison crashes on valueless size/defense/armor/spacing marker keywords
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot, mission-maker  
`src/scripts/veaf/veafCasMission.lua:515`  

**Issue.** markTextAnalysis splits each keyphrase with veaf.breakString, which returns {key, nil} when the keyword has no argument. For 'size'/'defense'/'armor'/'spacing' the code does `local nVal = tonumber(val)` then `if nVal <= 5 and nVal >= 1`. If a player types e.g. '_cas, size' (no number) or a non-numeric value, tonumber returns nil and `nil <= 5` raises a runtime error, aborting the whole command handler. veafTransportMission.markTextAnalysis has the identical pattern (lines 192-193 etc.).  

**Evidence.**
```
local nVal = tonumber(val)
      if nVal <= 5 and nVal >= 1 then
        switch.size = nVal
      end
```

**Fix.** Guard with `if nVal and nVal <= 5 and nVal >= 1 then` (and likewise for defense/armor/spacing here and in veafTransportMission).

> _Verifier:_ The vulnerability is real and player-reachable. veaf.breakString (veaf.lua:1171-1179) returns { key, nil } when a keyword has no space-separated argument, so val is nil for input like "_cas mission, size". markTextAnalysis is fed raw player-typed map-marker text: veafCasMission.lua:1281 calls executeCommand(pos, event.text, ...) which at line 419 calls markTextAnalysis. For size/defense/armor/spacing, val is nil (valueless) or a non-numeric string, and the handler crashes, aborting the whole com

### Lua · Combat mission elements

#### VMR-020 — Invalid Lua iteration crashes setAllElementsSkill
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafCombatMission.lua:702`  

**Issue.** `for _, element in self.elements do` uses a plain table where Lua's generic-for expects an iterator function. In Lua 5.1 this raises 'attempt to call a table value' the moment setAllElementsSkill() is invoked, so the method is dead/broken: any mission that calls it to override skills errors out.  

**Evidence.**
```
function VeafCombatMission:setAllElementsSkill(skill)
  for _, element in self.elements do
    element:setSkill(skill)
  end
```

**Fix.** Use `for _, element in pairs(self.elements) do` (or ipairs).

> _Verifier:_ Verified in src/scripts/veaf/veafCombatMission.lua. `self.elements` is initialized as a plain table (`objectToCreate.elements = {}`, lines 467/508) and populated with `table.insert(self.elements, value)` (line 628); it is a bare array table with no `__call` metamethod (the setmetatable calls only wire up `__index` for method dispatch). Line 702 `for _, element in self.elements do` puts a plain table in the iterator-function slot of Lua 5.1's generic-for. On the first iteration Lua invokes it as 

### Lua · Combat mission spawn

#### VMR-021 — Unguarded nil dereference when mist.teleportToPoint returns nil in combat mission activate
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafCombatMission.lua:895`  

**Issue.** In VeafCombatMission:activate the spawned group is teleported with `local _group = mist.teleportToPoint(vars, true)`. The skill-setting and unit-renaming loops are correctly wrapped in `if _group then`, but the line `_group.groupName = spawnedGroupName` sits between them with no guard. If teleportToPoint fails and returns nil (the code itself acknowledges this can happen elsewhere), this dereferences nil and errors out mid-activation, leaving the mission half-spawned.  

**Evidence.**
```
local _group = mist.teleportToPoint(vars, true)
          if _group then
            for _, unit in pairs(_group.units) do
              unit.skill = missionElement:getSkill()
            end
          end
          _group.groupName = spawnedGroupName
          if _group then
```

**Fix.** Move `_group.groupName = spawnedGroupName` inside an `if _group then` block (merge the two adjacent guards).

> _Verifier:_ Verified in src/scripts/veaf/veafCombatMission.lua: in VeafCombatMission:activate, line 889 assigns `local _group = mist.teleportToPoint(vars, true)`, lines 890-894 and 896-909 both guard their bodies with `if _group then`, but line 895 `_group.groupName = spawnedGroupName` is unguarded between them. mist.teleportToPoint (src/scripts/community/mist.lua:4352) genuinely returns nil/false on multiple paths: line 4410 (`if not newGroupData then return end`), line 4422 (no units -> return), and line 

### Lua · Farp build / coalition handling

#### VMR-022 — Dead type() guards make FARP coalition normalization ineffective
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafGrass.lua:1012`  

**Issue.** The guards `if type(farpCoalition == "number") then` and `if type(farpCoalition == "string") then` evaluate the equality first (a boolean) and then call type() on that boolean, which is always the string "boolean" — a truthy value. So BOTH branches always execute regardless of the real type of farpCoalition. As written, a numeric farpCoalition==1 is turned into "red", then the second block (also always entered) leaves farpCoalitionNumber based on the original number; a string input falls through the first block's else and is set to "blue". The intended type-dispatch never happens, so coalition can be mis-normalized (e.g. any non-1 number becomes "blue"/2 even for neutral), affecting the coalition/side of all spawned FARP units and the CTLD beacon.  

**Evidence.**
```
if type(farpCoalition == "number") then
  if farpCoalition == 1 then farpCoalition = "red" else farpCoalition = "blue" end
end
if type(farpCoalition == "string") then ...
```

**Fix.** Fix the parentheses: `if type(farpCoalition) == "number" then` and `if type(farpCoalition) == "string" then` (and normalize once, not in two always-executed blocks).

> _Verifier:_ The core defect is real. At veafGrass.lua:1012 and :1019, `type(farpCoalition == "number")` parses as `type( (farpCoalition == "number") )` = `type(boolean)` = the string "boolean", which is truthy, so BOTH if-blocks always execute regardless of the real type. Confirmed reachability: buildFarpUnits is fed unit data from veaf.mist.getAllUnitData(); MIST sets `.coalition` to a lowercase STRING ("red"/"blue"/"neutral") — see mist.lua:1022 `newTable.coalition = string.lower(coaData)` and :270/:298 —

### Lua · Human unit tracking / birth event

#### VMR-023 — onBirthEvent crashes when dynamic-slot groupId resolves to nil
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot, developer  
`src/scripts/veaf/veafRadio.lua:113`  

**Issue.** For dynamic-slot units the code tries several ways to obtain groupId (event.initiator.unitGroupId, then getGroup():getID()). If all fail, groupId stays nil, but the code still does veafRadio.humanGroups[groupId] = {} and table.insert(veafRadio.humanGroups[groupId].callsigns, ...). Indexing/assigning a Lua table with a nil key raises 'table index is nil', aborting the birth handler and preventing the radio menu from refreshing for that (and potentially subsequent) player. There is no guard that groupId is non-nil before it is used as a table key.  

**Evidence.**
```
local groupId = event and event.initiator and event.initiator.unitGroupId
...
if not veafRadio.humanGroups[groupId] then
  veafRadio.humanGroups[groupId] = {}
  ...
end
table.insert(veafRadio.humanGroups[groupId].callsigns, callsign)
```

**Fix.** After the groupId resolution attempts, bail out early (log a warning and return) when groupId is still nil, or fall back to a synthetic key such as unitName so the table index is never nil.

> _Verifier:_ Read veafRadio.lua lines 71-135. The code path is exactly as quoted. In the dynamic-slot branch, groupId is derived from event.initiator.unitGroupId (nil for raw DCS objects), then from getGroup():getID() (lines 92-98). Line 95 already guards `if grp then`, so if getGroup() returns nil, groupId stays nil with NO further guard before it is used as a table key. The dcs_mocks confirm getGroup() returning nil is a modeled reality (dcs_mocks.lua:326 `Unit.getGroup = function(unit) return nil end` and

### Lua · Skynet point defences

#### VMR-024 — Point-defence lookup relies on getEarlyWarningRadars(name), but Skynet ignores the argument
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort medium · roles: mission-maker, developer  
`src/scripts/veaf/veafSkynetIadsHelper.lua:622`  

**Issue.** When a user requests a specific SAM site to defend (pointDefense passed as a group name), the code calls iads:getEarlyWarningRadars(defended_name) at line 622 and again at line 731, expecting it to return the EWR matching that name (or nil). But the vendored Skynet API (src/scripts/community/skynet-iads-compiled.lua:1382 `function SkynetIADS:getEarlyWarningRadars()` returns `self:createTableDelegator(self.earlyWarningRadars)`) takes no argument and always returns a delegator over ALL EWRs. Consequently defended_EWR (line 623) is always a truthy table, so the `if defended_site then` branch always runs, the distance-based range validation (line 635) can be skipped when the SAM path is nil, and at line 731 `iads:getEarlyWarningRadars(defended_name):addPointDefence(addedSite)` adds the point defence to the delegator (i.e. broadcast to every EWR) instead of the named one. The named-EWR point-defence feature is silently wrong.  

**Evidence.**
```
local defended_EWR = iads:getEarlyWarningRadars(defended_name)
...
iads:getEarlyWarningRadars(defended_name):addPointDefence(addedSite)
```

**Fix.** Use the name-aware Skynet accessor (e.g. getEarlyWarningRadarByUnitName / a group-name equivalent) or iterate iads:getEarlyWarningRadars() and match dcsName yourself; treat the return of getEarlyWarningRadars() as a full list, never as a single named element.

> _Verifier:_ I read the vendored Skynet API: skynet-iads-compiled.lua:1382 defines `function SkynetIADS:getEarlyWarningRadars()` with NO parameter, returning `self:createTableDelegator(self.earlyWarningRadars)` (line 1383) over ALL EWRs. Lua silently discards the `defended_name` argument passed at veafSkynetIadsHelper.lua:622 and 731. createTableDelegator (line 1325) always returns a fresh table (SkynetIADSTableDelegator:create, line 1940) with a forwarder metatable, so it is ALWAYS truthy. Therefore: (1) at

#### VMR-096 — removeSkynetElement can nil-deref when the DCS group is gone
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafSkynetIadsHelper.lua:203`  

**Issue.** removeSkynetElement computes `local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElement)` which returns nil when the element's DCS representation no longer exists, then unconditionally does `veafSkynetNetwork.groups[dcsGroup:getName()] = nil`. The `---@diagnostic disable-next-line: need-check-nil` annotation acknowledges the missing nil check but suppresses it rather than handling it. If a point-defence SAM is destroyed/despawned at the moment Dcs point-defence mode removes it from the network, dcsGroup is nil and this line throws.  

**Evidence.**
```
local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElement)
---@diagnostic disable-next-line: need-check-nil
veafSkynetNetwork.groups[dcsGroup:getName()] = nil
```

**Fix.** Guard with `if dcsGroup then veafSkynetNetwork.groups[dcsGroup:getName()] = nil end`, or fall back to skynetElement.dcsName to clear the correct key.

#### VMR-138 — Duplicate self.pointDefences = {} and shadowed launchers local
🔵 **INFO** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veafSkynetIadsHelper.lua:423`  

**Issue.** removePointDefencesFromSkynetElement sets `skynetElement.pointDefences = {}` twice (lines 423 and 426) with no code between them that reads it, so the first assignment is dead. Separately, in veafSkynetIadsMonitor.lua GetStringSam, `local launchers = samSite:getLaunchers()` is declared at line 287 and then re-declared/shadowed at line 294 inside the ElementStructure block; the outer `launchers` and `iRangeMeters` (line 286) are never used. These are harmless but indicate leftover/duplicated code worth trimming.  

**Evidence.**
```
skynetElement.pointDefences = {}
  end

  skynetElement.pointDefences = {}
```

**Fix.** Remove the redundant second assignment and the unused outer launchers/iRangeMeters locals.

### Lua · Marker parameter parsing / dos

#### VMR-025 — Non-numeric 'multiplier' marker parameter aborts spawn with a runtime error
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot, mission-maker, server-admin  
`src/scripts/veaf/veafSpawnCore.lua:305`  

**Issue.** veaf.getRandomizableNumeric() returns nil when a parameter value is a non-numeric string with no dash (see veaf.lua:3033-3059: tonumber fails and there is no dash to parse). The 'multiplier' rule (_num("multiplier") in veafSpawnParser.lua:96) then sets options.multiplier = nil, overwriting the default of 1. executeCommand loops with `for i = 1, options.multiplier`, which raises "'for' limit must be a number" when the limit is nil. Any player able to drop a map marker (e.g. `_spawn group, name t72, multiplier x`) triggers a Lua error in the marker command handler, aborting the command and spamming the log. Several other _num rules (radius, spacing, speed, size, defense, etc.) have the same nil-injection but are defended downstream; multiplier is not.  

**Evidence.**
```
for i = 1, options.multiplier do   -- options.multiplier can be nil when veaf.getRandomizableNumeric returned nil
```

**Fix.** Make _num()/getRandomizableNumeric coerce a failed parse to a safe default (e.g. keep the previous value or 0), or clamp options.multiplier to a positive integer before the loop (e.g. `options.multiplier = tonumber(options.multiplier) or 1`).

> _Verifier:_ Verified the full chain in the actual code. veafSpawnParser.lua:20-24 (`_num`) calls `veaf.getRandomizableNumeric(val)`; veaf.lua:3097-3100 delegates to `getRandomizableNumeric_random`, which at 3031-3059 does `tonumber(val)` and, if nil with no dash present, returns nil. veafSpawnParser.lua:96 wires `multiplier` to plain `_num` (no validation, unlike `_numNonNegative` used for defense/armor/disperse), so `options.multiplier` (defaulted to 1 at line 563) is overwritten with nil for input like `m

### Lua · Zip/dictionary handling

#### VMR-038 — dictionaryNormalizer executes an untrusted dictionary file via loadfile/setfenv
⚪ **LOW** · Security flaw · verdict **PLAUSIBLE** · effort medium · roles: developer, mission-maker  
`src/scripts/other/dictionaryNormalizer.lua:19`  

**Issue.** loadTable() does `assert(loadfile(filePath))` then `setfenv(file, table); file()` on an arbitrary source path passed on the command line. The dictionary being normalized comes from a .miz mission dictionary, which is attacker-controlled untrusted input in this pipeline. Although setfenv sandboxes the environment to an empty table (so globals like os/io are not directly reachable inside the chunk), running loadfile+call on untrusted Lua still executes attacker code with whatever the empty environment plus any leaked upvalues allow, and any error/side effect happens at design time on the maintainer's machine. A safe dictionary should be parsed as data, not executed.  

**Evidence.**
```
local file = assert(loadfile(filePath))
...
setfenv(file, table)
file()
```

**Fix.** Parse the dictionary with a data-only deserializer (the project already ships luadata / safe loaders) instead of loadfile()+call; if execution is truly required, run inside a fully empty _ENV and wrap the call in pcall so a hostile dictionary cannot crash or side-effect the tool.

#### VMR-129 — dictionaryNormalizer and its helpers use print() and leak file handles on error
🔵 **INFO** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/other/dictionaryNormalizer.lua:99`  

**Issue.** This design-time tool uses bare print() for error reporting (lines 22, 102, 113) which the project style forbids for the runtime VEAF modules, though this is a standalone CLI script. More concretely, writeFileFile opens the file then, if loadTable earlier failed, loadTable returns nil silently (after printing) so downstream `pairsByKeys(table)` at line 122 indexes a nil table and crashes; and loadTable's `if not file` branch after `assert(loadfile(...))` is dead code because assert already errors on nil. The control flow around load failure is inconsistent.  

**Evidence.**
```
local file = assert(loadfile(filePath))
    if not file then
        print(string.format("Error while loading mission file [%s]", filePath))
        return
    end
```

**Fix.** Remove the unreachable `if not file` block, have loadTable return nil+message via pcall, and check the result before iterating; this is a CLI tool so print() is acceptable but the nil-return path must be handled by the caller.

### Lua · Marker remote execution

#### VMR-039 — Remote marker command runs stored Lua via mist.utils.dostring gated by shared static password
⚪ **LOW** · Security flaw · verdict **PLAUSIBLE** · effort medium · roles: pilot, mission-maker, server-admin  
`src/scripts/veaf/veafRemote.lua:228`  

**Issue.** veafRemote.executeRemoteCommand looks up a command in monitoredCommands and executes commandData.script through mist.utils.dostring (arbitrary Lua eval) once veafSecurity.checkPassword_L1(password) passes. The password is one of two hard-coded SHA-1 hashes shipped in veafSecurity.lua (PASSWORD_L0/L1), i.e. a shared secret baked into every public mission; anyone who extracts it from the .miz (or brute-forces the unsalted single-iteration SHA-1) can trigger these commands from a map marker. The requireAdmin path escalates to checkSecurity_L9, but L9/MM password tables are empty by default, so requireAdmin effectively falls back to L1/L0 too. The eval sink is only as safe as the operator remembering to keep monitoredCommands empty (it currently is, so this is latent), but the design stores executable Lua behind a shared static password with no per-user binding.  

**Evidence.**
```
if not (veafSecurity.checkPassword_L1(password)) then
    ...
  local commandData = veafRemote.monitoredCommands[command:lower()]
  if commandData then
    local scriptToExecute = commandData.script
    ...
      local result, err = mist.utils.dostring(scriptToExecute)
```

**Fix.** Treat the shipped L0/L1 hashes as public and never let them gate a Lua-eval sink. Require the MM/L9 password (properly provisioned per server, salted/iterated) for any dostring path, and document that monitoredCommands scripts are effectively RCE for anyone holding the shared password.

#### VMR-130 — Empty monitoredCommands makes the remote marker command path dead/unreachable
🔵 **INFO** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/scripts/veaf/veafRemote.lua:220`  

**Issue.** veafRemote.monitoredCommands is initialised empty and there is no function anywhere in the repo that inserts into it (no addCommandToMonitor / monitoredCommands[...] = assignment). Therefore executeRemoteCommand always hits the 'cannot find command' branch and the whole veafRemote marker command feature (the _remote#password path registered at PRIORITY_REMOTE) is effectively non-functional. Either the registration API was dropped or the feature is dead code; a maintainer should confirm intent, because the dostring sink is only dormant, not removed.  

**Evidence.**
```
veafRemote.monitoredCommands = {}
...
local commandData = veafRemote.monitoredCommands[command:lower()]
  if commandData then
    ...
  else
    veaf.loggers.get(veafRemote.Id):warn(string.format("veafRemote.executeRemoteCommand : cannot find command [%s]", command or ""))
```

**Fix.** Either remove the dead executeRemoteCommand/monitoredCommands machinery (and its dostring sink) or restore/ document the missing registration API. Do not leave a password-gated eval sink half-wired.

### Lua · Password handling

#### VMR-040 — Passwords hashed with unsalted single-round SHA-1; shared secrets committed in source
⚪ **LOW** · Security flaw · verdict **PLAUSIBLE** · effort large · roles: server-admin, mission-maker  
`src/scripts/veaf/veafSecurity.lua:51`  

**Issue.** PASSWORD_L0/PASSWORD_L1 are hard-coded SHA-1 digests in the repository, and _checkPassword hashes the candidate with a single unsalted sha1.hex() call and compares against the table. SHA-1 unsalted with one iteration is trivially brute-forceable/rainbow-tableable for the short passwords typically used, and the digests being public means the plaintext is discoverable offline. Every mission that ships these constants shares the same secret. This underpins the marker security levels (checkSecurity_L0/L1/L9) and the remote login.  

**Evidence.**
```
veafSecurity.PASSWORD_L0 = "47c7808d1079fd20add322bbd5cf23b93ad1841e"
veafSecurity.PASSWORD_L1 = "bdc82f5ef92369919a3a53515023ce19f68656cc"
veafSecurity.password_L0[veafSecurity.PASSWORD_L0] = true
```

**Fix.** Move real secrets out of source into per-server config (as intended for MM), use a salted, iterated KDF instead of bare SHA-1, and treat the committed L0/L1 values strictly as low-value/demo credentials that must not gate privileged actions.

### Lua · Marker author level

#### VMR-041 — getMarkerSecurityLevel conflates markId and username, weakening marker author trust
⚪ **LOW** · Security flaw · verdict **UNVERIFIED** · effort medium · roles: pilot, server-admin  
`src/scripts/veaf/veafSecurity.lua:591`  

**Issue.** getMarkerSecurityLevel walks world.getMarkPanels() to find the marker author, but if no panel matches it falls back to treating the passed markId AS the username ('_author = markId') and looks it up in veafRemote.getRemoteUser. Since checkSecurity_L0/L1/L9 skip the password when the author's level exceeds the threshold, an attacker who can influence what value reaches getMarkerSecurityLevel (or place a marker whose author string collides with a privileged registered username) could pass the level check without a password. The author string is client-supplied and not cryptographically bound to a level.  

**Evidence.**
```
if _author == nil then
    -- markId may actually be the username if called from veafRemote - yes I know it's ugly
    _author = markId
  end
  ...
  local _user = veafRemote.getRemoteUser(_author)
  if _user then
    return _user.level
  end
```

**Fix.** Separate the two lookups into distinct, explicit code paths (marker author vs. remote username) instead of overloading markId, and ensure the author->level mapping is derived from an authenticated UCID rather than a spoofable name string.

### Lua · Weather remote interface

#### VMR-042 — Remote fog command indexes veafWeather with attacker-supplied key without whitelisting
⚪ **LOW** · Security flaw · verdict **UNVERIFIED** · effort small · roles: server-admin, pilot  
`src/scripts/veaf/veafWeather.lua:1798`  

**Issue.** executeCommandFromRemote handles `fog <name>` by `local fogObject = veafWeather[uName]` where uName is `_name:upper()` derived from the player-supplied remote command text, then calls veafWeather.setAndActivateFog(fogObject) if the key exists. This is reachable only through the authenticated veafRemote path (password-gated), so it is not a straight RCE, but indexing the module table with arbitrary uppercased input is a fragile pattern: any uppercase module member that happens to exist (e.g. a constant or accidentally uppercase field) becomes selectable, and passing a non-VeafFog value into setAndActivateFog (which calls :disable/:enable on it) throws a runtime error. It should match against an explicit fog registry.  

**Evidence.**
```
local uName = _name:upper()
local fogObject = veafWeather[uName]
if fogObject then
  ...
  veafWeather.setAndActivateFog(fogObject)
```

**Fix.** Store selectable fog presets in a dedicated table (e.g. veafWeather.FogPresets[uName]) and look up only there, so remote input can never reach unrelated module members; validate the resolved value is a VeafFog before activating.

### Lua · Statistics reporting

#### VMR-071 — get_stat indexed by numeric loop key instead of stat type value
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: server-admin  
`src/scripts/Hooks/VEAF-Server-hook.lua:350`  

**Issue.** sendData iterates statisticsTypes with 'for key, value in pairs(...)' then calls net.get_stat(playerId, key), where key is the array index (1..8) but the values are then stored under pilotData.stats[value]. Whether net.get_stat expects the numeric enum index or something else, using the pairs KEY (index) while storing under the VALUE (name) is inconsistent; if the intended enum values differ from 1..8, or if pairs order is relied upon, the reported stats are mislabeled. ipairs and an explicit enum mapping would make intent correct and deterministic.  

**Evidence.**
```
for key, value in pairs(veafServerHook.statisticsTypes) do
            local stat = net.get_stat(playerId, key)
            ...
            pilotData.stats[value] = stat
        end
```

**Fix.** Use ipairs for the ordered list and pass the correct DCS stat enum for each type explicitly (a name->enum map), rather than relying on the array index equaling the enum.

### Lua · Chat command parsing

#### VMR-072 — parse() dereferences pilot.level after logging that pilot is unknown (potential nil index)
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: server-admin  
`src/scripts/Hooks/VEAF-Server-hook.lua:390`  

**Issue.** parse() logs a warning 'if not pilot' at line 383 but then unconditionally evaluates 'if pilot.level > 0' at line 390 and again in every branch. When pilot is nil (unknown UCID and not the admin id, or admin id with a pilots file missing ADMIN_FAKE_UCID), this indexes a nil value and raises an error, which is only contained because onChatMessage does not pcall parse(). The unknown-pilot case should return false early rather than crash.  

**Evidence.**
```
if not pilot then
        veafServerHook.logWarning(string.format("Unknown pilot [%s] sent chat message [%s])",...))
    end

    local _module, _command = message:match(veafServerHook.CommandParser)
    ...
    if pilot.level > 0 then
```

**Fix.** After the 'if not pilot' warning, 'return false' (or default pilot = { level = -1 }) so the rest of parse() cannot index a nil pilot.

### Lua · Http server loop

#### VMR-073 — dcs-fiddle create_server references undefined `id`, breaking every request path
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/other/dcs-fiddle-server.lua:561`  

**Issue.** handle_client_connection returns nothing (nil), so in the server loop 'local success, res = handle_client_connection(client)' yields success=nil (falsy), taking the else? no — the true branch requires success truthy; it is nil, so the error branch runs '__error("Failed to run client handler " .. res)' with res=nil, which errors on concatenation. And the success branch 'clients[id].receive_patten = res' references `id`, which is never defined in this scope (nil), so it would also error and has a typo 'receive_patten'. The whole post-connection bookkeeping is dead/broken; only the pcall in the outer timer keeps the server alive. This is latent because handle_client_connection swallows results, but any refactor will surface a crash.  

**Evidence.**
```
local success, res = handle_client_connection(client)
        if (not success) then
            __error("Failed to run client handler " .. res)
        else
            clients[id].receive_patten = res
        end
```

**Fix.** Have handle_client_connection return a status, wrap it in pcall, and remove the reference to the undefined `id` / the misspelled receive_patten (or track the client by the id assigned via get_client_id). Note this is a vendored third-party file; keep VEAF changes minimal but fix the crash-on-error path.

### Lua · Training spawn zones

#### VMR-074 — activateZone/deactivateZone crash on unknown or wrong-case zone name
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: mission-maker  
`src/scripts/other/trainingSpawnZone.lua:118`  

**Issue.** activateZone() and deactivateZone() look up `local _zone = trainingSpawnZone.zones[zoneName:lower()]` and immediately dereference `_zone.active` without checking that the zone exists. If a mission calls activateZone/deactivateZone with a name that was never registered (typo, or a zone registered under different text), _zone is nil and the script errors with 'attempt to index a nil value'. checkZone() (line 177) correctly guards with `if _zone then`, so the guard is simply missing in the two mutators.  

**Evidence.**
```
local _zone = trainingSpawnZone.zones[zoneName:lower()]
if not _zone.active then
```

**Fix.** Add `if not _zone then trainingSpawnZone.logWarning(...) return false end` in both activateZone and deactivateZone before touching _zone.active, mirroring checkZone.

> _Verifier:_ Verified against src/scripts/other/trainingSpawnZone.lua. Line 117 in activateZone does `local _zone = trainingSpawnZone.zones[zoneName:lower()]` and line 118 immediately does `if not _zone.active then` with no existence guard; deactivateZone (lines 139-140) is identical. registerZone (line 95-96) stores zones keyed by zoneName:lower(), so an unregistered or misspelled name yields nil, and indexing `_zone.active` raises 'attempt to index a nil value'. checkZone (line 176-177) correctly guards wi

#### VMR-075 — trainingSpawnZone.p references undefined veafServerHook on depth overflow
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/scripts/other/trainingSpawnZone.lua:54`  

**Issue.** The recursion-depth guard in trainingSpawnZone.p calls `veafServerHook.logError(...)`, but this standalone script never defines or requires veafServerHook (it uses trainingSpawnZone.logError everywhere else). This is a copy-paste leftover: if a table nesting ever exceeds MAX_LEVEL (20), the guard itself raises 'attempt to index a nil value (global veafServerHook)' instead of logging, converting a benign depth cap into a crash inside a debug logging path.  

**Evidence.**
```
veafServerHook.logError("max depth reached in p : "..tostring(MAX_LEVEL))
```

**Fix.** Call trainingSpawnZone.logError(...) instead of veafServerHook.logError(...).

### Lua · Data-export io robustness

#### VMR-076 — Output files written before io.open success is checked, crashing on any open failure
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: developer, mission-maker  
`src/scripts/veaf/dcsDataExport.lua:524`  

**Issue.** Both export blocks call io.open and immediately pass the result to writeln (which does file:write) BEFORE testing whether the handle is nil. The nil-guard 'if file then file:close() end' comes AFTER the write. If io.open returns nil (export_path directory missing, read-only, permission denied, or file locked), file is nil and writeln(file, ...) calls file:write on nil, raising 'attempt to index a nil value (local file)' and aborting the whole export. The trailing 'if file then' check is therefore pointless because a nil file already crashed one line earlier.  

**Evidence.**
```
Line 524-528: `local file = io.open(export_path .. "db.Units.lua", "w")` then `writeln(file, 'db={...}' ...)` then `if file then file:close() end`. Same pattern at 555-559: `file = io.open(export_path .. "dcsUnits.lua", "w")` / `writeln(file, DcsDataExport.serialize("units", values))` / `if file then file:close() end`. writeln (line 331) does `file:write(text .. "\r\n")` with no nil check.
```

**Fix.** Check the io.open result before writing: `local file = io.open(...); if not file then <log/return> end; writeln(file, ...); file:close()`. Capture and report the second return value from io.open (the error message) so the failure reason is visible in the DCS log.

> _Verifier:_ The code matches the claim exactly. writeln (dcsDataExport.lua:331-333) does `file:write(text .. "\r\n")` with no nil guard. At lines 524-528 and 555-559, `io.open(..., "w")` is called and its result is passed straight to writeln BEFORE the `if file then file:close() end` check. If io.open returns nil (permission denied, read-only dir, locked file), writeln(nil, ...) executes `nil:write(...)`, raising "attempt to index a nil value (local 'file')" one line before the trailing nil-guard is ever re

### Lua · Serialization error handling

#### VMR-077 — Undefined global logError() crashes the pretty-printer at max recursion depth
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: developer  
`src/scripts/veaf/dcsDataExport.lua:248`  

**Issue.** DcsDataExport._p calls logError(...) when the recursion level exceeds MAX_LEVEL (20). logError is never defined in this file (grep of the whole file finds no definition; the file defines DcsDataExport.loggers/Logger objects instead). On a deeply nested or self-referential table, instead of gracefully truncating, the call to the nil global logError raises 'attempt to call a nil value (global logError)', so the depth-guard that was meant to protect against runaway recursion itself crashes the export. Note _p also has no cycle detection, so a table containing a reference to itself will recurse to depth 20 and then hit this crash.  

**Evidence.**
```
Line 248: `logError("max depth reached in p : " .. tostring(MAX_LEVEL))`. No `logError` definition exists anywhere in the file (verified by grep). The file's logging API is `DcsDataExport.loggers.get(...):error(...)`.
```

**Fix.** Replace with the file's actual logger, e.g. `DcsDataExport.loggers.get(DcsDataExport.Id):error(...)`, or just `return ""` silently. Consider adding cycle detection (a visited-set keyed by table identity) so self-referential tables are handled instead of relying on the depth cap.

> _Verifier:_ Verified directly in src/scripts/veaf/dcsDataExport.lua. Line 248 calls logError("max depth reached in p : " .. tostring(MAX_LEVEL)) inside DcsDataExport._p when level > MAX_LEVEL (20). Grep of the whole file confirms no logError definition; the file's logging API is DcsDataExport.Logger:error / DcsDataExport.loggers.get(...):error(...) (lines 16-195). Searching all of src/scripts finds logError only as scoped table fields ctld.logError / csar.logError in veaf.lua — never a global. So in the dep

#### VMR-078 — Undefined global log used in serialize error branch (log:error)
⚪ **LOW** · Error / bug · verdict **PLAUSIBLE** · effort small · roles: developer  
`src/scripts/veaf/dcsDataExport.lua:427`  

**Issue.** In DcsDataExport.serialize, the fallback branch for an unserializable value type calls `log:error("Cannot serialize a $1", type(value))`. The global `log` is never defined in this file (the test harness only works because test/lua/test_dcsDataExport.lua injects a `log = { error = function() end }` shim before dofile). At real DCS ME runtime this branch would raise 'attempt to index a nil value (global log)'. Additionally the message uses `$1` placeholder syntax that is not Lua string formatting, so even if log existed the substitution would not happen. The path is normally unreachable (values are number/string/boolean/table) but is a latent crash and dead-looking error handler.  

**Evidence.**
```
Line 427: `log:error("Cannot serialize a $1", type(value))` inside the else of serializeToTbl. No `log` global defined in the file; test file line 42 comments '-- log.error is referenced inside DcsDataExport.serialize's error fallback' and shims it.
```

**Fix.** Use the module logger (`DcsDataExport.loggers.get(DcsDataExport.Id):error("Cannot serialize a %s", type(value))`) and standard %s formatting, matching the rest of the file's logging convention.

### Lua · Lua version portability

#### VMR-079 — Reliance on the implicit Lua 5.1 'arg' varargs table breaks under Lua 5.2+
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort medium · roles: developer  
`src/scripts/veaf/dcsDataExport.lua:91`  

**Issue.** formatText and the Logger:error/warn/info/debug/trace methods read the implicit `arg` table (`#arg`, `unpack(arg)`) for their vararg parameters instead of `...`/`{...}` and `select('#', ...)`. The implicit `arg` table for `...` was a Lua 5.0/5.1 feature and was removed in Lua 5.2+. DCS ships Lua 5.1 so this currently works, but it is fragile: if `arg` is nil (5.2+) the `#arg` in formatText is guarded by `if arg`, but the log methods call `unpack(arg)` unconditionally (lines 136/143/149/157/165), which would error under 5.2+. Even under 5.1 this is a well-known anti-pattern.  

**Evidence.**
```
Line 91: `if arg and #arg > 0 then text = text:format(unpack(arg)) end`. Line 136: `text = DcsDataExport.Logger.formatText(text, unpack(arg))` (and identical at 143, 149, 157, 165), passing the implicit `arg` rather than `...`.
```

**Fix.** Declare the varargs explicitly and forward them: `function ...:error(text, ...) ... formatText(text, ...)`, and in formatText use `local n = select('#', ...); if n > 0 then text = text:format(...) end`. Removes dependence on the deprecated implicit arg table.

### Lua · Pretty-printer api

#### VMR-080 — skip parameter mutated in place, corrupting caller's list and mixing array/hash keys
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/dcsDataExport.lua:199`  

**Issue.** DcsDataExport.p converts a caller-supplied array of skip keys into a set by writing boolean flags back into the SAME table: `for _, value in ipairs(skip) do skip[value] = true end`. This mutates the caller's table (side effect on an input argument) and leaves it in a hybrid state (original integer-indexed entries plus new string-keyed true flags). Calling p twice with the same skip table, or ipairs-iterating it afterwards, yields inconsistent results. It works today only because callers in this file pass nil for skip, but it is a latent bug for any future caller.  

**Evidence.**
```
Lines 197-204: `function DcsDataExport.p(obj, maxLevel, skip, serializeInLua) local skip = skip; if skip and type(skip) == "table" then for _, value in ipairs(skip) do skip[value] = true end end`.
```

**Fix.** Build a fresh lookup table instead of mutating the input: `local skipSet = {}; if type(skip)=='table' then for _,v in ipairs(skip) do skipSet[v]=true end end` and pass skipSet downward. Leaves the caller's table untouched and makes p idempotent.

### Lua · File export

#### VMR-081 — exportAsJson writes to a file handle without checking io.open succeeded
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: server-admin, developer  
`src/scripts/veaf/veaf.lua:3228`  

**Issue.** io.open can return nil (bad path, permission denied, read-only writedir, disk full). exportAsJson immediately calls writeln(file, header) on the result before testing it, so a failed open raises 'attempt to index a nil value' inside the export instead of a logged, recoverable error. The trailing 'if file then file:close() end' guard is unreachable because the crash already happened. The sibling writeLineToTextFile (line 3154-3159) does guard with 'if file then', so this is an inconsistency, not intended behaviour.  

**Evidence.**
```
local file = l_io.open(l_export_path .. filename, "w")
  writeln(file, header)
  writeln(file, table.concat(content, ",\n"))
  writeln(file, footer)
  if file then
    file:close()
  end
```

**Fix.** Guard the whole write block: `if not file then veaf.loggers.get(veaf.Id):error(...); return end` before the first writeln, mirroring writeLineToTextFile.

> _Verifier:_ Verified in src/scripts/veaf/veaf.lua: line 3228 `local file = l_io.open(l_export_path .. filename, "w")` is immediately followed at line 3229 by `writeln(file, header)`, and `writeln` (lines 3206-3208) does `file:write(text .. "\r\n")`, indexing `file`. If io.open returns nil (bad path, permission denied, read-only writedir, full disk), this raises "attempt to index a nil value", so the trailing `if file then file:close() end` guard at 3232-3234 is unreachable — exactly as claimed. The sibling 

### Lua · String parsing

#### VMR-082 — veaf.split / veaf.breakString break when the separator is a Lua pattern magic char
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/scripts/veaf/veaf.lua:1163`  

**Issue.** Both helpers interpolate the raw separator directly into a Lua pattern character class / anchored pattern via string.format('([^%s]+)', sep) and ('^([^%s]+)%s(.*)$'). If a caller passes a separator that is a magic char (%, ], ^, -) the resulting pattern is malformed or matches the wrong thing, silently returning bad splits. These are general-purpose helpers used across marker/command parsing, so a separator sourced from config or command text can produce silent mis-parsing rather than an error.  

**Evidence.**
```
local regex = ("([^%s]+)"):format(sep)
  for each in str:gmatch(regex) do
```

**Fix.** Escape the separator with veaf.escapeRegex(sep) before building the pattern in split() and breakString(), or document that sep must be a literal non-magic character.

### Lua · Serialization

#### VMR-083 — veaf.serialize emits non-reloadable text for table/function/userdata values
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veaf.lua:656`  

**Issue.** _basicSerialize returns tostring(s) for numbers, booleans, functions, tables and userdata, meaning a nested function/userdata value serializes to a literal like 'function: 0x7f...' or 'table: 0x...' which is not valid Lua and cannot be loaded back. The outer serialize_to_t only recurses into tables reached via its own table branch; any table reached through _basicSerialize (e.g. a metatable-wrapped value) yields a raw address. Callers that persist veaf.serialize output and later loadfile it will get a syntax error. At minimum the type(s)=='table'/'function'/'userdata' cases should error or be skipped rather than emitting an address string.  

**Evidence.**
```
if (type(s) == "number") or (type(s) == "boolean") or (type(s) == "function") or (type(s) == "table") or (type(s) == "userdata") then
        return tostring(s)
```

**Fix.** Restrict _basicSerialize's tostring branch to number/boolean; for function/table/userdata either error explicitly or emit nil with a logged warning, so serialized output stays loadable.

### Lua · Debug output

#### VMR-084 — vec3/vec2 pretty-print branch in veaf.p is dead code (#o is always 0)
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veaf.lua:821`  

**Issue.** The compact vector formatting is gated on '#o == 3' (and '#o == 2'), but o is a hash table {x=,y=,z=} with no array part, so the length operator returns 0 and the branch is never taken. Every vec3 therefore falls through to the generic multi-line table dump instead of the intended one-line '{x=.., z=.., y=..}'. Harmless functionally (debug only) but the condition is misleading and the feature silently does nothing.  

**Evidence.**
```
if o and type(o) == "table" and (o.x and o.z and o.y and #o == 3) then
    return string.format("{x=%s, z=%s, y=%s}", veaf.p(o.x), veaf.p(o.z), veaf.p(o.y))
```

**Fix.** Drop the '#o == 3' / '#o == 2' length checks (keep the x/y/z presence checks), or count keys explicitly, so the intended compact vector rendering actually fires.

### Lua · Air waves spawn positioning

#### VMR-085 — deployWaves/tickActive dereference triggerZone/zoneCenter without full nil handling
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafAirWaves.lua:1006`  

**Issue.** deployWaves builds zoneCenter with `local triggerZone = veaf.getTriggerZone(self.triggerZoneName); zoneCenter.x = triggerZone.x` whenever self.triggerZoneName is set. If the named trigger zone was deleted/renamed in the ME (getTriggerZone returns nil), this nil-derefs. setTriggerZone was recently hardened to tolerate a missing zone when a center is configured, but deployWaves still assumes the trigger zone resolves, so the tolerated case crashes at deploy time. _tickActive similarly assumes self.zoneCenter is non-nil in its else branch.  

**Evidence.**
```
if self.triggerZoneName then
      local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
      zoneCenter.x = triggerZone.x
      zoneCenter.z = triggerZone.y
```

**Fix.** Fall back to self.zoneCenter when getTriggerZone returns nil (mirror the setTriggerZone leniency) and guard self.zoneCenter before use in _tickActive.

### Lua · Carrier remote interface

#### VMR-086 — Remote start-operations duration parsing is dead / uses wrong variable
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`src/scripts/veaf/veafCarrierOperations.lua:1114`  

**Issue.** In executeCommandFromRemote the 'start' branch computes _duration but the condition 'type(_parameters) == number' can never be true: _parameters comes from a string:match (RemoteCommandParser) and is always a string or nil, so the custom duration is never honoured. Additionally, inside the block it calls tonumber(parameters) referencing the outer 'parameters' table argument rather than the local '_parameters', which is a copy/paste error that would not produce the intended number even if the type check were fixed.  

**Evidence.**
```
if _parameters and type(_parameters) == "number" then
  _duration = tonumber(parameters) or 45
end
```

**Fix.** Drop the impossible type check and parse the string directly: '_duration = tonumber(_parameters) or 45' (referencing _parameters, not parameters).

### Lua · Cas defense generation

#### VMR-087 — Unreachable armorBias branch: _actualDefense > 5 never true after clamp
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`src/scripts/veaf/veafCasMission.lua:609`  

**Issue.** _addDefenseForGroups clamps `if _actualDefense > 5 then _actualDefense = 6 end` (note: to 6, not 5) then immediately enters the per-multiple loop whose first branch is `if _actualDefense > 5 then` spawning the toughest air defense. Because the clamp sets it to exactly 6, the top branch IS reachable — but the sibling generateAirDefenseGroup clamps to 5, so the two functions disagree on the maximum tier. The `_actualDefense - 2` manpad-count `math.random(1, _actualDefense - 2)` with _actualDefense possibly 6 is fine, but the inconsistency (6 vs 5 ceiling) is almost certainly unintended and makes the '>5' tier only ever fire from this one path.  

**Evidence.**
```
if _actualDefense > 5 then
    _actualDefense = 6
  end
  ...
  for _ = 1, multiple do
    if _actualDefense > 5 then  -- only true because clamp set it to 6
```

**Fix.** Clamp to 5 like generateAirDefenseGroup (or intentionally document the level-6 'super' tier); align the two functions.

### Lua · Kill counting

#### VMR-088 — getRemainingEnemies mislabels damaged/dead units due to repeated getUnitLifeRelative calls
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, pilot  
`src/scripts/veaf/veafCombatMission.lua:778`  

**Issue.** The live/damaged classification calls veaf.getUnitLifeRelative(unit) three separate times per unit in the same branch. Because unit life can change between DCS API reads (and the function recomputes each time), a unit whose life crosses 1.0/whatsInAKill between calls can be double-counted or skipped, skewing the nbLiveUnits/nbDamagedUnits used by the kill-objective completion check. Capturing the value once removes the race and is also cheaper.  

**Evidence.**
```
if veaf.getUnitLifeRelative(unit) == 1.0 then
  ...
elseif veaf.getUnitLifeRelative(unit) > whatsInAKill then
  ... veaf.getUnitLifeRelative(unit) * 100 ...
```

**Fix.** Read `local life = veaf.getUnitLifeRelative(unit)` once and branch on the local.

### Lua · Event dispatch

#### VMR-089 — veafEventHandler.isEventEnabled returns nil for unknown events, silently letting them through
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veafEventHandler.lua:526`  

**Issue.** isEventEnabled only returns a value inside 'if checkEventKnown(...)'; for an unknown event id it falls off the end and returns nil. In onEvent the flow is guarded by an earlier checkEventKnown so this path is not currently reachable, but the function's contract is fragile: any future caller that treats a nil return as 'not disabled' (truthy check on the negation) would process an unrecognized event. isEventDelayedCallback (line 532) has the same shape.  

**Evidence.**
```
function veafEventHandler.isEventEnabled(eventNameOrId)
  if veafEventHandler.checkEventKnown(eventNameOrId) then
    return veafEventHandler.knownEvents[eventNameOrId].enabled
  end
end
```

**Fix.** Return an explicit boolean for the unknown branch (return false) so callers cannot misinterpret a nil fall-through.

### Lua · Missile guardian remote interface

#### VMR-090 — veafMissileGuardian remote/list handlers call undefined functions
⚪ **LOW** · Error / bug · verdict **PLAUSIBLE** · effort medium · roles: pilot, developer  
`src/scripts/veaf/veafMissileGuardian.lua:593`  

**Issue.** executeCommandFromRemote dispatches to veafMissileGuardian.listAvailableMissions, ActivateMission and DesactivateMission, and listActiveMissions iterates veafMissileGuardian.missionsDict — none of which are defined in this module (only listGuardians/ActivateGuardian/DesactivateGuardian exist). initialize() also calls veafMissileGuardian.dumpMissionsList, which does not exist. Any of these paths raises 'attempt to call a nil value' / indexing nil. The remote interface is effectively broken and initialize() itself will error if reached, though the module appears largely unfinished (getLargeScaleProtector returns nothing, so Guardian:onEvent's :setWeapon call also nil-derefs).  

**Evidence.**
```
veafMissileGuardian.listAvailableMissions()  -- not defined
...
for _, mission in pairs(veafMissileGuardian.missionsDict) do  -- missionsDict never created
...
veafMissileGuardian.dumpMissionsList(veaf.config.MISSION_EXPORT_PATH)  -- not defined
```

**Fix.** Either finish the module or remove/disable the dead remote-interface and initialize paths; at minimum reference the functions that actually exist (listGuardians, ActivateGuardian, DesactivateGuardian) and drop the dumpMissionsList call.

### Lua · Missile guardian object copy

#### VMR-091 — VeafMG_Guardian:copy corrupts protectedUnits/protectedZone deep copy
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: developer, mission-maker  
`src/scripts/veaf/veafMissileGuardian.lua:193`  

**Issue.** In :copy(), the protectedUnits loop writes into copy.protectedZone (`copy.protectedZone[unitName] = value`), and only afterwards is copy.protectedZone reset to {} and repopulated from self.protectedZone. The protectedUnits copy is therefore silently discarded and copy.protectedUnits is left as the fresh {} from :new(). A copied Guardian protects no units.  

**Evidence.**
```
copy.protectedUnits = {}
  for unitName, value in pairs(self.protectedUnits) do
    copy.protectedZone[unitName] = value
  end

  copy.protectedZone = {}
  for _, value in pairs(self.protectedZone) do
    table.insert(copy.protectedZone, value)
  end
```

**Fix.** Copy protectedUnits into copy.protectedUnits, and reset copy.protectedZone before (not after) copying zone points.

### Lua · Move marker parsing / dos

#### VMR-092 — Eager string.format("%d", val) on raw marker strings crashes veafMove parser
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot, server-admin  
`src/scripts/veaf/veafMove.lua:194`  

**Issue.** In veafMove.markTextAnalysis the debug logging formats the raw (string) parameter with %d BEFORE it is converted with tonumber. string.format("%d", val) is evaluated eagerly (the argument list is built regardless of log level). Lua 5.1 coerces numeric-looking strings but throws "bad argument ... (number has no integer representation)"/"number expected, got string" for non-numeric input such as `_move tanker, name X, speed fast`. Same pattern repeats for hdg (l.201), distance (l.208) and alt (l.215). A single crafted move marker aborts the command with a Lua error.  

**Evidence.**
```
veaf.loggers.get(veafMove.Id):debug(string.format("Keyword speed = %d", val))  -- val is str[2], a string, formatted before tonumber
```

**Fix.** Use %s (or tostring(val)) in these debug messages, or convert with tonumber first and log the converted value.

> _Verifier:_ The mechanism is real. At src/scripts/veaf/veafMove.lua:184-217, `val = str[2]` is a raw string (or nil) returned by veaf.breakString (veaf.lua:1171, uses str:match, no numeric validation). Lines 194/201/208/215 call string.format("%d", val) BEFORE tonumber (line 195). Lua always evaluates the argument list eagerly, so the format runs regardless of debug log level. In Lua 5.1 string.format("%d", s) coerces numeric-looking strings but throws "bad argument #2 to 'format' (number expected, got stri

### Lua · Srs position option

#### VMR-093 — Latitude/longitude formatted with %d, truncating fractional degrees
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: pilot, developer  
`src/scripts/veaf/veafRadio.lua:736`  

**Issue.** coord.LOtoLL returns latitude/longitude as floating-point degrees, but the SRS -L/-O position option is built with %d, truncating them to whole integers. The transmitted position for a positional SRS broadcast is therefore rounded to the nearest whole degree (tens of km of error), which defeats the purpose of passing eventPos.  

**Evidence.**
```
local lat, lon, alt = coord.LOtoLL(eventPos)
posOption = string.format("-L %d -O %d -A %d", lat, lon, alt)
```

**Fix.** Use a floating format such as %f/%.5f for lat and lon (altitude may stay integer).

### Lua · Sanctuary event handling

#### VMR-094 — Sanctuary event filter operator-precedence bug lets non-tracked BIRTH/DEAD events register
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: server-admin, developer  
`src/scripts/veaf/veafSanctuary.lua:804`  

**Issue.** The condition `event.id == S_EVENT_PLAYER_ENTER_UNIT or event.id == S_EVENT_BIRTH and _unitname and veafSanctuary.humanUnits[_unitname]` relies on `and` binding tighter than `or`. As written, a PLAYER_ENTER_UNIT event registers the unit even when it is not in humanUnits and even if _unitname is nil (the humanUnits guard only applies to the BIRTH branch). The `humanUnitsToFollow[_unitname or ""]` fallback then can key the follow-table under "", tracking a bogus entry. The symmetric LEAVE/DEAD branch has the same shape.  

**Evidence.**
```
if
      event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT
      or event.id == world.event.S_EVENT_BIRTH and _unitname and veafSanctuary.humanUnits[_unitname]
    then
```

**Fix.** Parenthesize the intent explicitly, e.g. `if (event.id == ENTER or event.id == BIRTH) and _unitname and veafSanctuary.humanUnits[_unitname] then`.

### Lua · Auth duration

#### VMR-095 — authenticate() silently ignores malformed timeout and mis-parses embedded digits
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: pilot, server-admin  
`src/scripts/veaf/veafSecurity.lua:531`  

**Issue.** veafSecurity.authenticate accepts minutes possibly as a string (from remote 'login <timeout>'). It only resets to the default when the string does NOT match %d+; when it DOES contain digits it passes the raw string straight into 'timer.getTime() + actualMinutes * 60'. A value like '10abc' matches %d+ so it is kept, then arithmetic on the string relies on implicit coercion and will error or coerce unexpectedly ('10abc'*60 fails). Conversely a purely non-numeric string falls back to default silently. The intent (tonumber) is not applied, so the watchdog schedule time can be wrong or throw.  

**Evidence.**
```
if type(actualMinutes) == "string" and not (actualMinutes:match("%d+")) then
    actualMinutes = veafSecurity.authDuration
  end
  ...
  veafSecurity.logoutWatchdog = mist.scheduleFunction(veafSecurity.logout, { true }, timer.getTime() + actualMinutes * 60)
```

**Fix.** Convert with tonumber and validate: local n = tonumber(actualMinutes); if not n or n <= 0 then n = veafSecurity.authDuration end, then use n. Anchor the pattern (^%d+$) if a string check is kept.

### Lua · Cap route / airspeed

#### VMR-097 — CAP speed computation ignores its mach argument, collapsing all leg speeds
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, pilot  
`src/scripts/veaf/veafSpawnAircraft.lua:859`  

**Issue.** convertSpeeds(speed, mach, altitude) is called with distinct mach values (0.3, 0.5, 0.63, 0.63) to derive four different leg speeds, but the function body hardcodes 0.3 and never reads its `mach` parameter. When no explicit speed is given, speed0..speed3 are therefore all identical (Mach 0.3 TAS) instead of the intended accelerating profile, so spawned CAP flights fly the whole route at the slowest transit speed.  

**Evidence.**
```
local function convertSpeeds(speed, mach, altitude)
  ...
  result = veaf.convertMachSpeed(0.3, altitude).TAS_ms  -- 'mach' parameter ignored
```

**Fix.** Use the passed argument: `veaf.convertMachSpeed(mach, altitude).TAS_ms`.

### Lua · Afac spawn limit

#### VMR-098 — AFAC spawn limit check is off-by-one and can index a taken callsign
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, server-admin  
`src/scripts/veaf/veafSpawnAircraft.lua:464`  

**Issue.** The guard uses `numberSpawned[coalition] > maximumAmount` (strictly greater). With maximumAmount=8 and exactly 8 callsigns, when 8 AFACs are already up (numberSpawned==8) the guard is false and the code proceeds. `newGroupName = callsigns[coalition][AFAC_num]` initializes with AFAC_num=numberSpawned=8, and the subsequent loop looking for a free callsign finds none (all taken), so it spawns a 9th AFAC reusing callsign #8's name and frequency, colliding with the existing one. The limit is effectively maximumAmount+1 and produces duplicate callsigns/frequencies.  

**Evidence.**
```
elseif veafSpawn.AFAC.numberSpawned[coalition] > veafSpawn.AFAC.maximumAmount then
  ... return false
```

**Fix.** Use `>=` for the limit check, and only proceed once a genuinely free callsign slot is found (bail out if the free-callsign loop finds none).

### Lua · Mfd visibility flag

#### VMR-099 — 'afac' command handler inverts the hiddenOnMFD flag relative to every other handler
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: mission-maker, pilot  
`src/scripts/veaf/veafSpawnAircraft.lua:1443`  

**Issue.** Every other command handler passes `not options.showMFD` as the hiddenOnMFD argument (unit l.1425, cap l.1462, all ground handlers, effects handlers), so an unset showMFD hides the spawn on the MFD. The afac handler instead passes `options.showMFD` directly (without negation) as the hiddenOnMFD parameter of spawnAFAC. This inverts the semantics: by default (showMFD falsey) the AFAC is passed hiddenOnMFD=false and stays visible, and adding `showmfd` would hide it — the opposite of the documented flag and of all sibling commands.  

**Evidence.**
```
veafSpawn.spawnAFAC(
  ... options.immortal,
  false,
  options.showMFD   -- other handlers pass `not options.showMFD`
)
```

**Fix.** Pass `not options.showMFD` to align the AFAC handler with the rest of the module (verify spawnAFAC's last param is indeed hiddenOnMFD).

### Lua · Cargo weight / shared state corruption

#### VMR-100 — In-place mutation of shared DCS unit descriptor when swapping cargo min/max mass
⚪ **LOW** · Error / bug · verdict **PLAUSIBLE** · effort small · roles: pilot, mission-maker  
`src/scripts/veaf/veafSpawnEffects.lua:89`  

**Issue.** veafUnits.findDcsUnit returns the actual object stored in dcsUnits.DcsUnitsDatabase (veafUnits.lua:165-176 returns `u` by reference, no copy). doSpawnCargo then writes back into unit.desc.maxMass / unit.desc.minMass to 'fix' an inverted range. Because unit is a shared reference, this permanently swaps the min/max mass of that cargo type in the global database for the rest of the mission, affecting every subsequent cargo spawn of the same type. It also mutates state the code merely intended to read.  

**Evidence.**
```
if massDelta < 0 then --never can be too careful around DCS
  local temp = unit.desc.maxMass
  unit.desc.maxMass = unit.desc.minMass
  unit.desc.minMass = temp
```

**Fix.** Compute local minMass/maxMass values without writing back to unit.desc (use `local lo, hi = math.min(unit.desc.minMass, unit.desc.maxMass), math.max(...)`), or deep-copy the unit before mutating.

### Lua · Convoy radio commands

#### VMR-101 — _findClosestConvoy aborts the whole search when one convoy has no position
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: pilot  
`src/scripts/veaf/veafSpawnGround.lua:677`  

**Issue.** When iterating spawnedConvoys, if veaf.getAveragePosition returns nil for any single convoy (e.g. a fully destroyed/despawned convoy still lingering in the table), the function logs an error and `return nil` immediately, abandoning the search. A destroyed convoy that hasn't been pruned therefore hides all other still-alive convoys from 'mark/stop/move closest convoy', instead of being skipped.  

**Evidence.**
```
if not averageGroupPosition then
  veaf.loggers.get(veafSpawn.Id):error("cannot get average position of %s", veaf.p(unitName))
  return nil
end
```

**Fix.** Replace the early `return nil` with a `goto`/continue-style skip (e.g. wrap the distance logic in `if averageGroupPosition then ... end`) so a single positionless convoy doesn't blind the rest.

### Lua · Laser code validation

#### VMR-102 — convertLaserToFreq accepts codes outside the valid DCS laser range in the low digits
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: pilot, mission-maker  
`src/scripts/veaf/veafSpawnParser.lua:234`  

**Issue.** convertLaserToFreq validates only the overall range 1111..1688, but DCS laser codes are octal-like: each of the last three digits must be 1..8. Values such as 1119, 1190, 1199 pass the range check and produce a bogus frequency (e.g. laserCD computed from a '9' digit), which is then stored as options.laserCode and handed to CTLD JTAC lasing. The result is a JTAC advertising a code that no aircraft can actually receive.  

**Evidence.**
```
if laser and laser >= 1111 and laser <= 1688 then
  local laserB = math.floor((laser - 1000) / 100)
  local laserCD = laser - 1000 - laserB * 100
```

**Fix.** Validate each digit is in 1..8 (reject any code whose tens or units digit is 0 or 9) before converting, returning nil otherwise.

### Lua · Weather atis

#### VMR-103 — getAtis new-ATIS detection triggers on any lower date component, not strict chronology
⚪ **LOW** · Error / bug · verdict **UNVERIFIED** · effort small · roles: pilot, mission-maker  
`src/scripts/veaf/veafWeather.lua:1131`  

**Issue.** The check to decide whether the cached ATIS is stale ORs together `dateTimeZulu.year > ... or .month > ... or .day > ... or .hour > ...`. Because the components are compared independently rather than as a full timestamp, this both over- and under-fires. Example: cached ATIS at 2024-06-10 14:00, current time 2024-07-10 09:00 (a month later): year equal, month greater -> declares new ATIS correctly by luck; but current 2024-06-11 09:00 (next day, earlier hour): day greater -> new ATIS, fine; however cached at day 20 hour 05, current day 10 hour 09 of the next month: month>month true so it works, yet cached hour 20 vs current hour 09 same day incorrectly keeps old ATIS across a genuine hour rollover only when higher components are equal. The independent-OR comparison does not implement 'strictly later time' and yields wrong staleness decisions around month/day boundaries.  

**Evidence.**
```
dateTimeZulu.year > atisInEffect.DateTimeZulu.year
  or dateTimeZulu.month > atisInEffect.DateTimeZulu.month
  or dateTimeZulu.day > atisInEffect.DateTimeZulu.day
  or dateTimeZulu.hour > atisInEffect.DateTimeZulu.hour
```

**Fix.** Compare full timestamps lexicographically (only fall through to the next component when the higher ones are equal), or convert both to absolute seconds and compare, to detect 'current hour block is later than the recorded one'.

### Lua · Asset lookup

#### VMR-109 — Asset info/dispose/respawn scan the whole list instead of keyed lookup
⚪ **LOW** · Optimization · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veafAssets.lua:91`  

**Issue.** veafAssets.assets is already keyed by asset name (buildAssetsDatabase: veafAssets.assets[asset.name] = asset), and a veafAssets.get(name) helper exists, yet info(), dispose() and respawn() each iterate the entire assets table with a linear 'for _, asset in pairs' to find a match by name. This is redundant O(n) work and duplicated three times.  

**Evidence.**
```
for _, asset in pairs(veafAssets.assets) do
  if asset.name == name then
    theAsset = asset
  end
end
```

**Fix.** Replace the three linear scans with 'local theAsset = veafAssets.assets[name]' (or veafAssets.get(name)).

### Lua · Cache lifecycle

#### VMR-110 — VeafCache.getCachedData never evicts expired entries, growing the table unbounded
⚪ **LOW** · Optimization · verdict **UNVERIFIED** · effort small · roles: server-admin, developer  
`src/scripts/veaf/veafCacheManager.lua:113`  

**Issue.** getCachedData returns nil for an expired entry but leaves the stale record in self.cache; only an explicit delCachedData or an overwriting setCachedData ever removes a key. For a long-running server that caches many short-TTL keys (per-unit or per-position lookups), the cache table grows without bound and holds references to their data values, a slow memory leak. There is no periodic sweep.  

**Evidence.**
```
local cachedData = self.cache[key]
    if cachedData then
      if cachedData.endoflife == VeafCache.LIVE_FOREVER or cachedData.endoflife >= timer.getTime() then
        return cachedData
      end
    end
  end
  return nil
```

**Fix.** On an expired hit, set self.cache[key] = nil before returning nil, and/or add an occasional sweep so non-re-requested expired keys are reclaimed.

### Lua · Sanctuary action logging

#### VMR-117 — Dead / nonsensical double-wrapped _recordAction call in veafSanctuary
⚪ **LOW** · Readability · verdict **UNVERIFIED** · effort small · roles: server-admin, developer  
`src/scripts/veaf/veafSanctuary.lua:116`  

**Issue.** recordAction wraps _recordAction inside another _recordAction: `veafSanctuary._recordAction(veafSanctuary._recordAction(...))`. _recordAction returns nil, so the outer call always receives nil and writes nothing — the inner call does the work, the outer is dead code with a misleading log prefix ('INFO SCRIPTING: VEAF - I - ' concatenated onto an already-formatted message).  

**Evidence.**
```
veafSanctuary._recordAction(veafSanctuary._recordAction(" INFO    SCRIPTING: VEAF - I - " .. _message))
```

**Fix.** Call _recordAction once: `veafSanctuary._recordAction(" INFO ... " .. _message)`.

### Lua · Script structure

#### VMR-132 — Module-level export code runs at load time as a script side effect (poor testability / reuse)
🔵 **INFO** · Refactoring · verdict **UNVERIFIED** · effort medium · roles: developer  
`src/scripts/veaf/dcsDataExport.lua:523`  

**Issue.** Everything from line 523 onward (opening files, calling browseUnits 13 times, sorting, serializing, writing to disk) executes as an unconditional side effect the moment the file is dofile'd. This is why the unit test (test_dcsDataExport.lua) has to monkey-patch io.open to a no-op and inject empty db.Units tables and a log shim before it can even load the module. Wrapping the export in a function (e.g. DcsDataExport.run()) would let tests load the module without triggering disk writes, and would let the API be reused, while keeping the current entrypoint as a single call at the bottom.  

**Evidence.**
```
Lines 523-559 are top-level statements. Test file comment lines 16-22: 'dcsDataExport.lua writes unit data to disk at load time; we replace io.open with a no-op and supply the empty database tables it iterates.'
```

**Fix.** Extract the export sequence into `function DcsDataExport.run(export_path) ... end` and call it once at the bottom. Improves testability and matches the Worker/Manager separation the project favours.

### Lua · Dead code

#### VMR-133 — Unused local spawnCapFunction
🔵 **INFO** · Refactoring · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veafRadio.lua:873`  

**Issue.** local spawnCapFunction = function() end is defined but never referenced anywhere in the module, leftover dead code.  

**Evidence.**
```
-- helper functions for user menus
local spawnCapFunction = function() end
```

**Fix.** Delete the unused local.

### Lua · Marker text analysis logging

#### VMR-136 — veafCombatMission password keyword uses string.format with no format specifier
🔵 **INFO** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veafCasMission.lua:508`  

**Issue.** `string.format("Keyword password", val)` passes val as an extra argument with no %s in the format string, so val is silently ignored; the same dead-argument pattern appears in veafTransportMission (line 185). Harmless but misleading and flagged by linters. Note the value being logged is a user password, so the current behavior of NOT printing it is actually preferable — fix by removing the unused arg rather than adding a specifier.  

**Evidence.**
```
veaf.loggers.get(veafCasMission.Id):debug(string.format("Keyword password", val))
```

**Fix.** Drop the unused `val` argument (do not add a %s — avoid logging the password).

### Lua · Srs marker parsing

#### VMR-137 — Duplicate 'path' keyword handling in markTextAnalysis
🔵 **INFO** · Readability · verdict **UNVERIFIED** · effort small · roles: developer  
`src/scripts/veaf/veafRadio.lua:235`  

**Issue.** The 'path' keyword is handled by two identical elseif branches (lines 215 and 235). The second branch is unreachable dead code because the first already matches key:lower() == 'path'. It adds noise and suggests an incomplete edit.  

**Evidence.**
```
elseif key:lower() == "path" then  -- line 215
  switch.path = val
...
elseif key:lower() == "path" then  -- line 235 (dead)
  switch.path = val
```

**Fix.** Remove the second duplicate 'path' elseif branch.


---

## 📄 Doc — 26 findings

### Doc · Conversion profiles / staleness

#### VMR-007 — CONVERT_OTHER says conversion profiles are "coming next" but foothold already ships
🟠 **HIGH** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`doc/mission-maker/CONVERT_OTHER.en.md:8`  

**Issue.** The opening blockquote states the conversion profile is a future item — EN: "is carried by a *conversion profile* (coming next)", FR: "(à venir)" — yet the very next section documents the bundled `foothold` profile as shipped, and `src/python/veaf-tools/veaf_libs/data/convert-profiles/foothold.yaml` exists. The claim is stale in both language versions and contradicts the rest of the same page.  

**Evidence.**
```
CONVERT_OTHER.en.md:8-11 "...is carried by a *conversion profile* (coming next). See ADR 0007." vs CONVERT_OTHER.en.md:34 "the bundled `foothold` profile:" (and confirmed file `foothold.yaml`).
```

**Fix.** Reword the blockquote to state that conversion profiles exist today (foothold is bundled) and that more may be added, in both CONVERT_OTHER.md and CONVERT_OTHER.en.md.

### Doc · Bilingual parity / broken links

#### VMR-008 — English guides link to French .md pages instead of .en.md
🟠 **HIGH** · Documentation · verdict **UNVERIFIED** · effort medium · roles: mission-maker  
`doc/mission-maker/README.en.md:69`  

**Issue.** Every internal link in the English mission-maker pages targets the FRENCH sibling (`.md`) rather than the English (`.en.md`) version, even though `.en.md` variants exist for all of them (GUIDE.en.md, MIGRATION_GUIDE.en.md, CONVERT_OTHER.en.md, and every scripts/*.en.md). An English reader clicking any of these is dropped into French content. Affected: README.en.md lines 20, 52-59 (module table), 69-71 (Next Steps); GUIDE.en.md line 27 and all scripts/*.md links (e.g. lines 423-428); MIGRATION_GUIDE.en.md lines 47, 360-361; FOOTHOLD.en.md lines 12, 169. This is a systematic FR/EN divergence, not a one-off.  

**Evidence.**
```
README.en.md:69 `| [Full Guide](GUIDE.md) | Detailed setup, configuration, and build workflow |`  and  FOOTHOLD.en.md:12 `The per-command detail lives in [CONVERT_OTHER](CONVERT_OTHER.md)` — both point at the French files while `GUIDE.en.md` / `CONVERT_OTHER.en.md` exist.
```

**Fix.** Rewrite internal links in every `*.en.md` file to their `.en.md` targets (e.g. `GUIDE.en.md`, `MIGRATION_GUIDE.en.md`, `CONVERT_OTHER.en.md`, `scripts/veafSpawn.en.md`). Consider a link-lint CI check to keep English pages linking English.

### Doc · Coalition constants

#### VMR-014 — Coalition ID mapping is backwards (1=blue/2=red) — DCS uses RED=1, BLUE=2
🟡 **MEDIUM** · Error / bug · verdict **CONFIRMED** · effort small · roles: developer, mission-maker  
`doc/LUA_API_REFERENCE.en.md:74`  

**Issue.** The conventions table states `coalition — Coalition ID: 0=neutral, 1=blue, 2=red`. This is reversed from the actual DCS/VEAF convention: `coalition.side` in test/lua/dcs_mocks.lua is `{ NEUTRAL = 0, RED = 1, BLUE = 2 }`, and veaf.getCountryForCoalition() in src/scripts/veaf/veaf.lua maps coalitionId 1→"red" and 2→"blue". A developer following this doc to filter or stamp coalitions will invert every red/blue decision. The same wrong mapping is repeated at line 1639 (the marker-event structure comment: `0=neutral, 1=blue, 2=red`). The identical error exists in the FR file at doc/LUA_API_REFERENCE.md lines 74 and 1638 (`0=neutre, 1=bleu, 2=rouge`).  

**Evidence.**
```
doc line 74: `- `coalition` - Coalition ID: 0=neutral, 1=blue, 2=red`  |  dcs_mocks.lua:138 `side = { NEUTRAL = 0, RED = 1, BLUE = 2 }`  |  veaf.lua getCountryForCoalition: `if coalitionId == 1 then coalitionName = "red" elseif coalitionId == 2 then coalitionName = "blue"`
```

**Fix.** Correct both languages to `0=neutral, 1=red, 2=blue` at LUA_API_REFERENCE.en.md lines 74 and 1639, and LUA_API_REFERENCE.md lines 74 and 1638.

> _Verifier:_ Verified all four cited locations. doc/LUA_API_REFERENCE.en.md line 74 states `coalition - Coalition ID: 0=neutral, 1=blue, 2=red` and line 1639 repeats `0=neutral, 1=blue, 2=red`; the FR file doc/LUA_API_REFERENCE.md has the same at lines 74 and 1638 (`1=bleu, 2=rouge`). The actual convention is the reverse: test/lua/dcs_mocks.lua:138 defines `side = { NEUTRAL = 0, RED = 1, BLUE = 2 }`, and src/scripts/veaf/veaf.lua getCountryForCoalition (lines 2655-2658) maps coalitionId 1→"red" and 2→"blue".

### Doc · Broken references

#### VMR-026 — CONTRIBUTING.md links to a non-existent doc/developer/GUIDE.fr.md
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort small · roles: developer  
`CONTRIBUTING.md:5`  

**Issue.** The French guide link points to doc/developer/GUIDE.fr.md, which does not exist. Under the mkdocs i18n suffix structure (docs_structure: suffix, fr is default), the French file is doc/developer/GUIDE.md and the English is GUIDE.en.md. So the FR link 404s while every other CONTRIBUTING link (line 30 uses GUIDE.md#development-environment, which is correct and whose anchor exists) is fine. A contributor clicking the top-of-file FR guide link hits a dead link.  

**Evidence.**
```
CONTRIBUTING.md:5 '> 🇫🇷 Guide du développeur complet : [doc/developer/GUIDE.fr.md](doc/developer/GUIDE.fr.md)'. `ls doc/developer/GUIDE.fr.md` → 'No such file or directory'; only GUIDE.md (FR default) and GUIDE.en.md exist.
```

**Fix.** Change the link target to doc/developer/GUIDE.md (the French default under the suffix i18n scheme).

### Doc · Test-suite count

#### VMR-027 — Developer GUIDE says "31 test suites" but there are 34 (contradicts TESTING.md)
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort small · roles: developer  
`doc/developer/GUIDE.md:64`  

**Issue.** The repo tree comment and the CI-jobs table in the Developer GUIDE both state 31 Lua test suites. The repository actually has 34 `test/lua/test_*.lua` files, and doc/TESTING.md (line 19) itself states "34 Lua test suites". So the GUIDE is both factually wrong and internally inconsistent with the sibling TESTING page. The identical stale number appears in the EN GUIDE at doc/developer/GUIDE.en.md lines 65 and 464 ("31 suites" / "All 31 test suites pass").  

**Evidence.**
```
GUIDE.md:64 `│   └── lua/                      # Tests unitaires Lua (31 suites)` and GUIDE.md:463 `| `Lua Unit Tests` | Les 31 suites de tests passent |` — vs `ls test/lua/test_*.lua | wc -l` → 34
```

**Fix.** Update both the tree comment and the CI-jobs row to 34 in GUIDE.md (lines 64, 463) and GUIDE.en.md (lines 65, 464), matching TESTING.md.

### Doc · Module-file count

#### VMR-028 — Developer GUIDE says "34 files" for src/scripts/veaf/ but there are 41
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort small · roles: developer  
`doc/developer/GUIDE.md:54`  

**Issue.** The repository-layout tree annotates `src/scripts/veaf/` as "Modules Lua runtime (34 fichiers)". The directory actually contains 41 `.lua` files (e.g. veafQraCore, veafQraLogistics, veafSpawnCore, veafSpawnAircraft, veafSpawnEffects, veafSpawnGround, veafI18n, etc. were split out). Same stale count in EN at doc/developer/GUIDE.en.md line 55 ("Lua runtime modules (34 files)"). Note this also does not match LUA_API_REFERENCE's "33+ modules" phrasing.  

**Evidence.**
```
GUIDE.md:54 `│   ├── scripts/veaf/             # Modules Lua runtime (34 fichiers)` — vs `ls src/scripts/veaf/*.lua | wc -l` → 41
```

**Fix.** Update the count to 41 (or use "40+") in GUIDE.md line 54 and GUIDE.en.md line 55.

### Doc · In-page anchors / toc

#### VMR-029 — French GUIDE Table of Contents links are broken (slug vs explicit heading id)
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`doc/mission-maker/GUIDE.md:15`  

**Issue.** Four TOC entries in GUIDE.md link to auto-generated French slugs, but the target headings carry explicit English `{#id}` overrides that win on GitHub, so the links are dead: `#configurer-les-modules` → heading id `configuring-modules`; `#profils-de-build` → `build-profiles`; `#exemples-de-configuration` → `configuration-examples`; `#intégration-ctld-et-csar` → `ctld-and-csar-integration`. GUIDE.en.md does NOT have this problem — its TOC already uses the explicit ids — so this is also an FR/EN divergence.  

**Evidence.**
```
GUIDE.md:15 `7. [Configurer les modules](#configurer-les-modules)` while GUIDE.md:236 `## Configurer les modules {#configuring-modules}` — the explicit `{#configuring-modules}` overrides the auto-slug, breaking the TOC link.
```

**Fix.** Point the four FR TOC anchors at the explicit ids (`#configuring-modules`, `#build-profiles`, `#configuration-examples`, `#ctld-and-csar-integration`), or drop the explicit `{#id}` overrides from the FR headings.

### Doc · Debug logging / klogg profile

#### VMR-030 — Migration guide says Klogg VEAF profile is "planned" but it already ships
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker, server-admin  
`doc/mission-maker/MIGRATION_GUIDE.en.md:349`  

**Issue.** The 'Reading the logs' section claims the Klogg highlight profile is not yet available: EN "A VEAF highlight profile for Klogg is planned — once available it will be committed to the repository...", FR "Un profil Klogg pour VEAF est prévu". It already ships at `tools/klogg/veaf.conf` and is documented as available in GUIDE.md/GUIDE.en.md (lines 630-631). Stale in both language versions of the migration guide.  

**Evidence.**
```
MIGRATION_GUIDE.en.md:349 "A VEAF highlight profile for Klogg is planned — once available it will be committed to the repository and announced on the VEAF Discord." — but `tools/klogg/veaf.conf` exists and GUIDE.en.md:631 already links `[tools/klogg/veaf.conf](../../tools/klogg/veaf.conf)`.
```

**Fix.** Replace the 'planned' sentence in MIGRATION_GUIDE.md and MIGRATION_GUIDE.en.md with a pointer to the shipped `tools/klogg/veaf.conf`, matching the wording already in GUIDE.

### Doc · Shortcuts config

#### VMR-031 — Shortcuts config table names the enable field `enable` while examples use `enabled`
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`doc/mission-maker/scripts/veafShortcuts.en.md:51`  

**Issue.** The field-reference table lists the module toggle as `enable`, but every YAML example on the same page (and the shipped default mission.yaml, which uses `enabled: true`) uses `enabled`. Although the generator happens to accept both spellings (lua_config_generator lists "enable" and "enabled"), the table contradicts the examples and the shipped default, so a reader copying the table field name gets an inconsistent key. Same slip exists in the FR page.  

**Evidence.**
```
veafShortcuts.en.md:51 "| `enable` | boolean | `true` | No | Enable or disable the module |" while the YAML block at :38-46 and the minimal example at :63 use `enabled: true`; src/defaults/mission-folder/mission.yaml:80 uses `enabled: true`. Same in veafShortcuts.md:51.
```

**Fix.** Change the table field name from `enable` to `enabled` in both veafShortcuts.md and veafShortcuts.en.md to match the examples, the RADIO/NAMEDPOINTS/COMBATZONE tables, and the shipped default.

### Doc · Weather

#### VMR-032 — Weather page Purpose and F10-menu sections diverge between FR and EN
🟡 **MEDIUM** · Documentation · verdict **UNVERIFIED** · effort medium · roles: mission-maker, pilot  
`doc/mission-maker/scripts/veafWeather.md:8`  

**Issue.** The FR and EN weather pages are structurally out of sync. EN documents the module as "Two distinct roles" (design-time injection vs runtime) and renders the F10 menu as a table with an "Available to / secured" column; FR gives only a single terse Purpose paragraph and a plain bullet list for the F10 menu with no security column. FR additionally has a runtime chat line ("accessibles depuis le chat multijoueur (avec le hook serveur VEAF) : atc") that EN omits, while EN has a "No parameters required" note under Enable that FR omits. Readers of one language get information the other lacks.  

**Evidence.**
```
veafWeather.md:8-9 "Fournit des rapports météo..." (one paragraph) and :78-83 bullet list + "chat multijoueur ... : atc" vs veafWeather.en.md:10-13 "Two distinct roles: 1. Design-time... 2. Runtime..." and :69-76 table with "Available to" column and "No parameters required" at :30.
```

**Fix.** Reconcile the two pages so both carry the same Purpose framing, the same F10-menu table (including the secured Fog-settings row), and the same runtime/chat note.

### Doc · Security passwords

#### VMR-033 — Warn that a well-known default L1 password ships active
⚪ **LOW** · Security flaw · verdict **PLAUSIBLE** · effort small · roles: mission-maker, server-admin  
`doc/mission-maker/scripts/veafSecurity.en.md:43`  

**Issue.** veafSecurity.lua hardcodes and activates a shared, publicly-known L1 password at load time (veafSecurity.PASSWORD_L1 = "bdc82f5ef92369919a3a53515023ce19f68656cc"; veafSecurity.password_L1[...] = true, lines 51-54), plus a public L0 password. The docs present clearing defaults as an ordinary optional step ("Clear default passwords and set your own") without warning that a mission left unmodified is authenticable by anyone who knows the public VEAF password. This is exactly the kind of untrusted-input/secrets warning the security page should carry.  

**Evidence.**
```
Both veafSecurity.md:43-49 and veafSecurity.en.md:43-49 show `veafSecurity.password_L1 = {}` / `password_L1[sha1.hex(...)] = true` under a neutral heading with only a soft note "Do not commit plain-text passwords"; no warning that the shipped default L1 hash is public and active until cleared.
```

**Fix.** Add an explicit security warning: the module ships with a public default L1 (and L0) password that is active by default; any public server MUST clear password_L0/password_L1 and set its own hashes, or sensitive commands are effectively unprotected.

#### VMR-124 — Security page documents only three levels; Mission-Master (MM) level is undocumented
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker, server-admin  
`doc/mission-maker/scripts/veafSecurity.en.md:26`  

**Issue.** The permission-levels table lists only L0/L1/L9 and states "Three permission levels", but veafSecurity.lua also defines a fourth Mission-Master tier: veafSecurity.password_MM, checkPassword_MM, checkSecurity_MM. Mission makers securing MM-only actions have no documentation for it.  

**Evidence.**
```
veafSecurity.en.md:10 "Three permission levels with SHA-1 hashed passwords" and table :26-30 (L0/L1/L9 only); veafSecurity.lua:48 `veafSecurity.password_MM = {}`, :578 `function veafSecurity.checkPassword_MM`, :643 `function veafSecurity.checkSecurity_MM`.
```

**Fix.** Either document the MM (Mission Master) level and its password_MM slot, or explicitly note it is an internal/advanced tier not intended for mission-maker configuration.

### Doc · Spawn commands

#### VMR-043 — GUIDE (EN) tips use invalid `group N` option for `_spawn unit`
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot  
`doc/pilot/GUIDE.en.md:311`  

**Issue.** Same error as the French GUIDE: `_spawn unit, name BTR-80, group 5` for 'dispersed APC targets'. The spawn parser has no numeric `group` key; `group` is a subcommand and boolean flag, while the count of units is set by `multiplier` (documented correctly at line 139 of this file). The `group 5` argument is ignored, so a pilot following this tip gets one unit instead of five. Correct form: `_spawn unit, name BTR-80, multiplier 5`.  

**Evidence.**
```
GUIDE.en.md:311 `_spawn unit, name BTR-80, group 5` vs veafSpawnParser.lua:286 `options.group = true` and :96 multiplier key (no numeric `group` option)
```

**Fix.** Replace `group 5` with `multiplier 5`.

> _Verifier:_ Verified the doc and the parser. GUIDE.en.md:311 reads `_spawn unit, name BTR-80, group 5`. In veafSpawnParser.lua the option-key table (lines 84-209) has NO `group` key; `multiplier` (line 96, default 1 at line 563) is the only count option. `group` appears only as command matches: line 284 `match = SpawnKeyphrase .. " group"` with init `options.group = true` (line 286), a boolean subcommand flag, not a per-token numeric option. veafSpawnCore.lua:305 loops `for i = 1, options.multiplier do`, so

#### VMR-044 — GUIDE tips use invalid `group N` option for `_spawn unit`
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot  
`doc/pilot/GUIDE.md:311`  

**Issue.** The helicopter tip suggests `_spawn unit, name BTR-80, group 5` 'pour des cibles APC dispersées'. There is no numeric `group` option in the spawn parser: `group` is a distinct subcommand (`_spawn group`) and internally a boolean flag (`options.group = true`), not a per-unit count. The option that sets how many units spawn is `multiplier` (documented correctly earlier in this same GUIDE at line 139). As written, `group 5` is silently ignored and the pilot gets a single unit, not five. The correct command is `_spawn unit, name BTR-80, multiplier 5`.  

**Evidence.**
```
GUIDE.md:311 `_spawn unit, name BTR-80, group 5` vs veafSpawnParser.lua:286 `options.group = true` (boolean, subcommand) and :96 `{ keys = { "multiplier" }, apply = _num("multiplier") }` — no numeric `group` key exists
```

**Fix.** Replace `group 5` with `multiplier 5` in the helicopter tip.

> _Verifier:_ Verified all quoted evidence. GUIDE.md:311 does say `_spawn unit, name BTR-80, group 5`. In veafSpawnParser.lua the option-key table (lines ~84-147) contains no `keys = { "group" }` entry (grep for `"group"` returns only an unrelated comment at line 619 and no key definition), so `group` is NOT a per-unit numeric option. `group` is only a distinct subcommand at lines 283-286 that sets `options.group = true` (boolean). The correct count option is `multiplier` (line 96: `{ keys = { "multiplier" },

### Doc · Cas training

#### VMR-045 — README (EN) advertises non-existent "CAS Mission → Generate" menu path
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot  
`doc/pilot/README.en.md:22`  

**Issue.** Same defect as the French README: the table row 'F10 menu → CAS Mission → Generate' points to a menu command that does not exist. veafCasMission.lua builds no 'Generate' radio command; CAS is triggered by a `_cas` marker (Keyphrase '_cas'), consistent with GUIDE.en.md step 1 'place a `_cas` marker'. The README therefore contradicts the code and the English GUIDE.  

**Evidence.**
```
README.en.md:22 `| **CAS training** | F10 menu → CAS Mission → Generate | ...` vs veafCasMission.lua:1081-1090 (menu builds 'Target information' / 'Skip current objective', no Generate) and :28 `veafCasMission.Keyphrase = "_cas"`
```

**Fix.** Replace with the marker flow, e.g. 'F10 marker: `_cas` (then use the CAS MISSION submenu)'.

> _Verifier:_ README.en.md:22 lists "F10 menu → CAS Mission → Generate" for CAS training, but veafCasMission.lua builds no "Generate" radio command. The initial menu builder veafCasMission.buildRadioMenu (line 1259-1264) adds only "HELP" to the "CAS MISSION" submenu (RadioMenuName = "CAS MISSION", line 45). After a mission spawns, addCommandToSubmenu/addSecuredCommandToSubmenu calls (lines 1081-1097) add only "Target information", "Skip current objective", "Target markers" submenu, and smoke/flare requests — 

#### VMR-046 — README advertises non-existent "CAS Mission → Generate" menu path
⚪ **LOW** · Error / bug · verdict **CONFIRMED** · effort small · roles: pilot  
`doc/pilot/README.md:22`  

**Issue.** The README 'What can you do' table tells pilots to start CAS via 'Menu F10 → CAS Mission → Generate'. No such 'Generate' command exists in the CAS radio menu. In veafCasMission.lua the only radio commands built are 'Target information', 'Skip current objective' and the 'Target markers' submenu (Request smoke / Request illumination); there is no Generate entry. CAS missions are created by placing a `_cas` marker (Keyphrase '_cas'), which is exactly what GUIDE.md step 1 says. So the README contradicts both the code and its own companion GUIDE, sending pilots hunting for a menu item that isn't there.  

**Evidence.**
```
README.md:22 `| **Entraînement CAS** | Menu F10 → CAS Mission → Generate | ...` vs veafCasMission.lua:1090 `addSecuredCommandToSubmenu("Skip current objective", ...)` / :1081 `"Target information"` (no Generate command) and :28 `veafCasMission.Keyphrase = "_cas"`
```

**Fix.** Change the CAS row to reference the marker-based flow, e.g. 'F10 marker: `_cas` (then use the CAS MISSION submenu)', matching GUIDE.md.

> _Verifier:_ Verified against the actual code and docs. doc/pilot/README.md:22 tells pilots "Entraînement CAS | Menu F10 → CAS Mission → Generate". In src/scripts/veaf/veafCasMission.lua the radio menu (lines 1081-1097) builds only "Target information", "Skip current objective" (addSecuredCommandToSubmenu, line 1090), and a "Target markers" submenu with "Request smoke on target area" and "Request illumination flare over target area". No "Generate" command exists anywhere (grep for Generate in the file return

### Doc · Module count / factual accuracy

#### VMR-119 — README claims "34 Lua modules" — contradicts the source tree (41) and the API reference ("33+")
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer, pilot  
`README.md:28`  

**Issue.** The '34 Lua runtime modules' figure appears six times in README (lines 28, 89, 100, 128, 139, 164) in both FR and EN, including the claim that the Lua API Reference documents 'all 34'. But src/scripts/veaf/ contains 41 .lua files, and the linked doc/LUA_API_REFERENCE.md itself states '33+ modules Lua'. The three numbers (34 / 41 / 33+) are mutually inconsistent, so at least the README's precise '34' and its 'all 34' claim about the API ref are factually wrong.  

**Evidence.**
```
README.md:28 '| [Lua API Reference](doc/LUA_API_REFERENCE.md) | Full API for all 34 Lua runtime modules |'; `ls src/scripts/veaf/*.lua | wc -l` → 41; doc/LUA_API_REFERENCE.md:48 '**33+ modules Lua**'.
```

**Fix.** Reconcile the count. Either use an approximate phrasing ('40+ Lua modules') consistently across README and LUA_API_REFERENCE, or state the exact current count; drop the 'all 34' claim about the API reference since it does not document 34.

### Doc · Fr/en cross-links

#### VMR-120 — MISSION_YAML_REFERENCE.en.md cross-links point at French GUIDE.md instead of .en.md
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker, developer  
`doc/MISSION_YAML_REFERENCE.en.md:465`  

**Issue.** The English mission.yaml reference mostly links to English pages (line 226 correctly uses `mission-maker/GUIDE.en.md#ctld-and-csar-integration`), but two links still target the French page: line 465 `[Developer Mode](developer/GUIDE.md#developer-mode)` and line 626 `[Mission Maker Guide](mission-maker/GUIDE.md)`. Both `.en.md` targets exist (doc/developer/GUIDE.en.md, doc/mission-maker/GUIDE.en.md), so an English reader is bounced to the French guide (and line 465's anchor `#developer-mode` only exists on the English page anyway, so the FR link also lands on a wrong/absent anchor).  

**Evidence.**
```
MISSION_YAML_REFERENCE.en.md:465 `> See the [Developer Mode](developer/GUIDE.md#developer-mode) section...` and :626 `- [Mission Maker Guide](mission-maker/GUIDE.md) — complete workflow`
```

**Fix.** Change the two links to `developer/GUIDE.en.md#developer-mode` and `mission-maker/GUIDE.en.md` for consistency with the rest of the EN page.

### Doc · Command reference completeness

#### VMR-121 — convert-other missing from the Design-Time Tools command table
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`doc/mission-maker/GUIDE.md:318`  

**Issue.** The 'Outils de conception' / 'Design-Time Tools' table lists `convert-v5` but omits `convert-other`, even though convert-other is a first-class registered command (src/python/veaf-tools/veaf_tools/commands/convert_other.py) with two dedicated guide pages (CONVERT_OTHER, FOOTHOLD). A mission maker scanning this table for the way to adopt a third-party mission won't find it. Present in both GUIDE.md and GUIDE.en.md.  

**Evidence.**
```
GUIDE.md:318 `| `convert-v5` | Migre un dossier mission v5 vers le format v6 |` — the adjacent `convert-other` command has no row in the table.
```

**Fix.** Add a `convert-other` row to the tools table in GUIDE.md and GUIDE.en.md, linking to CONVERT_OTHER, so the third-party adoption path is discoverable from the main guide.

### Doc · Bilingual parity

#### VMR-122 — dcs-radio-specs reference page has no English version
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort medium · roles: mission-maker  
`doc/mission-maker/dcs-radio-specs.md:1`  

**Issue.** Every other mission-maker page ships as a FR/EN pair, but `dcs-radio-specs.md` is French-only (headings 'Avions', 'Hélicoptères', 'Appareils critiques', body prose in French) with no `dcs-radio-specs.en.md`. Per the project's bilingual policy this reference page (used to explain inject-presets frequency validation) has no English counterpart, so English mission makers get a French-only page.  

**Evidence.**
```
dcs-radio-specs.md:1 `# Spécifications des fréquences radio DCS` — directory listing shows only `dcs-radio-specs.md`, no `.en.md` sibling (unlike all other pages in doc/mission-maker/).
```

**Fix.** Add `dcs-radio-specs.en.md` mirroring the French page (the frequency table is language-neutral; translate the prose sections and column headers).

### Doc · Combat zones

#### VMR-123 — veafCombatZone.en.md is missing the "See Also" heading
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker  
`doc/mission-maker/scripts/veafCombatZone.en.md:343`  

**Issue.** The EN combat-zone page drops straight from the Training Mode section's horizontal rule into the See-Also bullet list with no "## See Also" heading, unlike the FR page (which has "## Voir aussi") and every other page in the cluster. The links render as an orphaned list under Training Mode.  

**Evidence.**
```
veafCombatZone.en.md:342-344 shows `---` then directly `- [veafCasMission]...` with no heading, whereas veafCombatZone.md:343-345 has `## Voir aussi` before the same links.
```

**Fix.** Add `## See Also` above the bullet list at line 344 in veafCombatZone.en.md to match the FR page and the rest of the cluster.

### Doc · Assets menu

#### VMR-125 — FR/EN asset menu labels diverge (Ressources vs Assets) from real 'ASSETS' label
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: pilot  
`doc/pilot/GUIDE.en.md:178`  

**Issue.** The EN GUIDE documents 'F10 → VEAF → Assets → Tankers → [Name] → Info' while the FR GUIDE documents 'F10 → VEAF → Ressources → Ravitailleurs → …'. The two pages therefore name the same in-game menu differently (Assets vs Ressources) and both add a Tankers/AWACS grouping level that the code does not build. The actual menu label is the hardcoded English 'ASSETS' with assets paginated directly beneath it, so the EN label is closer but the sub-submenu structure is still fictional in both.  

**Evidence.**
```
GUIDE.en.md:178 `**F10 → VEAF → Assets → Tankers → [Name] → Info**` vs GUIDE.md:178 `**F10 → VEAF → Ressources → Ravitailleurs → [Nom] → Infos**`; code label veafAssets.lua:30 `RadioMenuName = "ASSETS"`
```

**Fix.** Align both pages on the real 'ASSETS' menu and remove the non-existent Tankers/AWACS sub-submenu level.

#### VMR-126 — Asset menu path documents intermediate submenus that don't exist in-game
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: pilot  
`doc/pilot/GUIDE.md:178`  

**Issue.** The GUIDE describes the asset menu as 'F10 → VEAF → Ressources → Ravitailleurs → [Nom] → Infos' and the mermaid diagram shows a 'Ressources' node with Ravitailleurs/AWACS/Porte-avions children. In the code the asset menu is a single top-level submenu literally named 'ASSETS' (veafAssets.RadioMenuName = "ASSETS", built via addSubMenu(RadioMenuName) with no 'Resources' parent), and individual assets are added as paginated entries directly under it — there is no 'Ressources' wrapper nor a 'Ravitailleurs'/'AWACS' grouping sub-submenu. Pilots looking for a 'Ressources' entry will not find one; the actual in-game label is the English 'ASSETS'. (The EN GUIDE at least matches the real label 'Assets', but still invents the Tankers/AWACS sub-submenu level.)  

**Evidence.**
```
GUIDE.md:178 `**F10 → VEAF → Ressources → Ravitailleurs → [Nom] → Infos**` and :60-62 mermaid `Res[Ressources] --> Tank[Ravitailleurs]` vs veafAssets.lua:30 `veafAssets.RadioMenuName = "ASSETS"` and :78 `veafAssets.rootPath = veafRadio.addSubMenu(veafAssets.RadioMenuName)` (no Resources parent; :83 paginates assets directly)
```

**Fix.** Describe the real structure: F10 → VEAF → ASSETS → [asset name] → Info/Respawn, and drop the invented 'Ressources'/'Ravitailleurs' intermediate levels (or note the on-screen label is 'ASSETS').

### Doc · Security and permissions

#### VMR-127 — Permission table maps to Public/Pilots/Admin, not the code's L0/L1/L9 password model
⚪ **LOW** · Documentation · verdict **UNVERIFIED** · effort small · roles: pilot  
`doc/pilot/GUIDE.md:278`  

**Issue.** The Security section presents three levels 'Public / Pilotes (non-spectateurs) / Admin' and says `_auth [MOT_DE_PASSE]` unlocks restricted commands. The marker-based security in veafSecurity actually uses three password tiers L0/L1/L9, and the `_auth` marker checks the L1 password (checkPassword_L1). The 'Pilotes = joueurs non-spectateurs' tier is not part of the marker-password system at all (that non-spectator notion belongs to the remote/pilot.level path), so a pilot reading this may expect a 'pilot' level unlock that the `_auth` marker does not provide. The abstraction is reasonable for a pilot audience but the middle 'Pilots = non-spectator' row does not correspond to any marker-command gate.  

**Evidence.**
```
GUIDE.md:281 `| Pilotes | Joueurs non-spectateurs |` and :287 `_auth [MOT_DE_PASSE]` vs veafSecurity.lua:462 `if not (bypassSecurity or veafSecurity.checkPassword_L1(options.password)) then` and :33-35 `LEVEL_L0=90 / LEVEL_L1=10 / LEVEL_L9=1`
```

**Fix.** Clarify that `_auth` unlocks via a mission password (L1) and either drop or reframe the 'Pilots = non-spectator' row, which does not gate marker commands.

### Doc · Test count

#### VMR-139 — Overview test count "~1000 tests" disagrees with ROADMAP's "~915 tests"
🔵 **INFO** · Documentation · verdict **UNVERIFIED** · effort small · roles: developer  
`doc/TESTING.md:19`  

**Issue.** TESTING.md (and TESTING.en.md line 19) state the suite totals "~1000 tests", while doc/ROADMAP.md line 56 and doc/ROADMAP.en.md line 50 state "31 suites, ~915 tests". Both the suite count (31 vs 34) and the aggregate test count disagree between the two pages. Summing the per-suite counts in the TESTING table lands near ~1000, so ROADMAP is the stale side, but the two docs should be reconciled.  

**Evidence.**
```
TESTING.md:19 `Le projet compte 34 suites de tests Lua ... totalisant ~1000 tests` vs ROADMAP.md:56 `Tests unitaires Lua (31 suites, ~915 tests)`
```

**Fix.** Reconcile the numbers: update ROADMAP (FR+EN) to 34 suites / ~1000 tests, or make TESTING cite the same figure, so the two pages agree.

### Doc · Shortcuts security

#### VMR-140 — Shortcuts security list omits `-point` and `-longsmoke` from the bypass-security aliases
🔵 **INFO** · Documentation · verdict **UNVERIFIED** · effort small · roles: mission-maker, server-admin  
`doc/mission-maker/scripts/veafShortcuts.en.md:133`  

**Issue.** The Security section names the always-available (bypass-security) utility aliases as `-smoke, -signal, -light, -tacan, -jtac, -afac`. In veafShortcuts.lua the full set with setBypassSecurity(true) also includes `-point` and `-longsmoke`. The phrasing uses "like", so it is not strictly wrong, but a security-conscious admin reading the list may not realize `-point` and `-longsmoke` also skip the permission check.  

**Evidence.**
```
veafShortcuts.en.md:133 "Some utility aliases (like `-smoke`, `-signal`, `-light`, `-tacan`, `-jtac`, `-afac`) bypass security"; veafShortcuts.lua:1043-1047 `-point ... setBypassSecurity(true)`, :1430-1433 `-longsmoke ... setBypassSecurity(true)`.
```

**Fix.** Add `-point` and `-longsmoke` to the listed bypass-security aliases (or state the list is illustrative and point to ALIASES.md for the authoritative set).


---

## Appendix A — Coverage & method

- **Reviewers:** 20 cluster agents — 6 Python (core I/O & config, mission generation, CLI app, mission‑builder, injectors/weather, build tooling), 6 Lua (core runtime, spawning, combat/zones, radio/navigation, weather/IADS/misc, **security/server**), 5 doc (pilot, mission‑maker guides, mission‑maker script pages, developer/reference, root/security), plus a gap‑fill pass for `aircrafts_injector`, `waypoints_injector`, `spawn_data_injector`, `mission_tools`, `mission_extractor`, `doc_chatbot`, `build_profiles.py` and `dcsDataExport.lua`.
- **Verification:** every security/bug finding ≥ medium was independently re‑checked by an adversarial verifier instructed to default to *refuted* on doubt; 6 were dropped.
- **Not covered for quality (by design):** vendored `src/scripts/community/*` (mist, CTLD, CSAR, AIEN, TheUniversalMission, Hercules, Skynet) and `luadata` — inspected only for the trust boundary; and the generated `dcsUnits.lua` data table.
- **Caveat:** UNVERIFIED findings (optimization / readability / doc / low‑severity) are reviewer‑asserted with file:line evidence but were not adversarially re‑checked. Confirm before acting on low‑severity items.


## Appendix B — Findings considered and refuted

These were raised by a reviewer but an independent adversarial verifier read the code and refuted them. Recorded for transparency.

| File:line | Title | Type | Why refuted |
|---|---|---|---|
| `src/python/veaf-tools/veaf_tools/commands/prepare.py:245` | Broad except in prepare swallows typer.Abort/Exit and masks the real error | bug | The claim's mechanism (broad `except Exception` catches `typer.Abort`) is technically true — I confirmed in logger.py:92-104 that `logger.error` defaults `exception_type=typer.Abort` and unconditionally raises it (line 1 |
| `src/scripts/veaf/veafTime.lua:149` | getMissionDateTime produces wrong yday after a day/month rollover | bug | Two claims are bundled and both fail. (1) The headline "wrong yday after rollover" is false: lines 133-147 normalize iDay/iMonth/iYear across month/year boundaries, then line 149 computes yday from the already-normalized |
| `src/scripts/veaf/veafSecurity.lua:424` | Remote login grants auth on client-supplied level with no password check | security | The code at veafSecurity.lua:424-428 does authenticate the mission on `_pilot.level >= LEVEL_L1` (10) with no password, but the finding's premise that `level` is "client-supplied" is false. Tracing the chain: in VEAF-Ser |
| `src/scripts/Hooks/VEAF-Server-hook.lua:282` | Admin identification by chat sender id==1 lets non-admins act as admin if pilot table lacks the fake UCID | security | The headline claim — "lets non-admins act as admin" — is not supported by the code or DCS semantics. At VEAF-Server-hook.lua:282 the admin substitution only occurs when `from == 1`. `from` is the DCS `net` caller/player  |
| `SECURITY.md:42` | SECURITY.md omits the autoexec.cfg unsanitize / net.dostring_in server risk of the bundled TUM script | security | I read SECURITY.md (lines 41-47) and docs/exploration/TUM-EXPLOIT.md in full. The finding is a documentation-completeness opinion, not a security vulnerability. (1) SECURITY.md is a standard GitHub security POLICY docume |
| `src/python/veaf-tools/mission_tools/mission_exporter.py:222` | Markdown date formatting raises on partial DCS date tables | bug | Read src/python/veaf-tools/mission_tools/mission_exporter.py L215-247 (to_markdown) and export.py (only caller). The `date` table is parsed from DCS `.miz`/mission files where `date` is `{Day=N, Month=N, Year=N}` with Lu |
