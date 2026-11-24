# FIX-CONVERT-V5-SILENT-LOSSES — what `convert-v5` drops without saying so

Status: ✅ done — all five tickets shipped 2026-08-17 (6.15). Closed 2026-10-03 without Sharko's two harnesses, which never came after seven weeks (David's call): the fixes stand on their own tests · archived 2026-11-24

Origin: [#722](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/722),
[#723](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/723),
[#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) — filed by Sharko in
August 2026, re-measured by him against v6.14.2, and opened as a lot on 2026-08-17 by
`CHORE-GITHUB-ISSUE-TRIAGE`, which found nothing tracking them.

## The one sentence they share

A v5 mission converted to v6 **behaves differently and nothing says which settings stopped
applying**. Three surfaces, one failure mode: the loss is silent. `backup_v5/` and
`convert-v5-report.md` keep the original, so this is not data loss — it is a mission that looks
converted and is not, with no line anywhere pointing at what changed.

Sharko's own framing is the one to build on, and it sets the bar lower than "v6 must express
everything":

> not that v6 can express everything, but that what it cannot express is **said**.

The precedent is already in our code: `MigrationResult.callback_hints` writes
`-- [v6 migration] callbacks not migrated. Set them manually after init:` into the generated Lua
(`config_migrator.py:92`, emitted at `:1637`). A declared loss is acceptable; an undeclared one is
not.

## Everything below was re-verified here on 2026-08-17

Not taken from the reports — each claim re-measured against `develop` at `4b0c4d55`, because a
third-party report is a hypothesis, however well argued.

| Claim | Verified |
|-------|----------|
| The chain walker stops at the first line not starting with `:` | `config_migrator.py:1404-1411` — exactly that, no string-continuation case |
| The six `combat_zones` setters are absent from the migrator | `setShowUnitsList`, `setShowZonePositionInfo`, `setEnableUserActivation`, `setEnableSmokeAndFlare`, `setCompletable`, `disableRadioMenu` → **0 occurrences each**; the control `setBriefing` → 5, so the grep discriminates |
| `completable` is emitted but never extracted | Emission exists at `lua_config_generator.py:656` (`_emit_combat_zone_def`); `setCompletable` appears nowhere in `config_migrator.py`. **The round-trip really is asymmetric** — a hand-written `mission.yaml` can set it, a converted one never will |
| `missionConfig.lua` is deleted and the migrated buffer never written | `v5_converter.py:1144-1151`, and the comment at `:1153-1158` **says so itself** — the buffer is only written by the standalone `migrate-config` command |
| Importing `ConfigMigrator` now pulls pydantic | **Proven by running it**: `pydantic loaded: True`. Chain is `config_migrator:19` → `lua_config_generator:28` → `checklists:29` |

One thing the reports did not spell out and that matters for the fix: the information Sharko wants
**already exists on another path**. `migrate-config` writes the migrated buffer, where unrecognised
lines survive as commented-out code; `convert-v5` generates `mission-script.lua` from scratch
instead (measured at 349 bytes, header only) and deletes the original. So this is not "we cannot
see the unrecognised settings" — it is "the command everyone uses throws away what the other
command shows".

## Scale, from Sharko's corpus (1898 zones, 28 mission parts, 4 campaigns)

- **302 briefings of 1864 truncated**, worst case 137 characters migrated as **6**
  (`CombatZone_MOA2-Hawash`)
- `setShowUnitsList` / `setShowZonePositionInfo` / `setEnableUserActivation` /
  `setEnableSmokeAndFlare`: **1135 zones each**, all passing `false`
- `disableRadioMenu`: **171 zones** — deliberately hidden zones that reappear in the F10 menu,
  under the placeholder names their authors gave them *because* they were never meant to be seen
- `setCompletable(false)`: **82 zones**. This is the consequential one: without it
  `isCompletable()` lets the watchdog arm, and a zone spawning no RED unit is deactivated at the
  first tick (~60 s), broadcasting "all enemies destroyed" and chaining to the next zone — a
  campaign progression break, not a display glitch
- **14 of 28 scalar keys dropped**, including two families that change behaviour in silence:
  security (`veafSecurity.PASSWORD_L1`, `password_L1`, `authenticated`,
  `veafCarrierOperations.DisableSecurity`) and IADS (`veafSkynet.DelayForStartup`, `DynamicSpawn`,
  `PointDefenceMode`)

Because the framework defaults are `true` and these settings are used to turn things **off**,
losing them does not fall back to a neutral value — it **inverts the behaviour**.

## Order, and why the net comes second

01 → 02 → 03 → 04 → 05.

Ticket 01 first because every later measurement is taken through the extractor: while a multi-line
briefing truncates the chain, setters after it are invisible, so tickets 03 and 04 would be
measuring on truncated input and would under-count their own work.

Ticket 02 — declaring what is not migrated — comes **before** carrying the keys, even though it is
the cheaper half of what the issues ask. It is the instrument: once unrecognised assignments are
collected and reported, the list it prints *is* the work list for 03 and 04, and it shrinks
measurably as each key lands. Shipping the keys first would leave us carrying the ones we happened
to know about, with no way to see the rest.

Ticket 05 is unrelated to the losses and is here because it was found in the same thread: it costs
one import and it is what lets an outside harness like Sharko's keep measuring us.

## Scope

| # | Ticket | Issue |
|---|--------|-------|
| 01 | [The chain walker accepts string continuations](FIX-CONVERT-V5-SILENT-LOSSES.md) | #722 |
| 02 | [Declare the settings that are not migrated](FIX-CONVERT-V5-SILENT-LOSSES.md) | #725, #723 |
| 03 | [Carry the missing `combat_zones:` keys](FIX-CONVERT-V5-SILENT-LOSSES.md) | #723 |
| 04 | [Carry the fourteen dropped scalars](FIX-CONVERT-V5-SILENT-LOSSES.md) | #725 |
| 05 | [Stop pulling pydantic into the migrator](FIX-CONVERT-V5-SILENT-LOSSES.md) | #725 (comment) |

## Out of scope, stated rather than assumed

- **The `getMissionEditorZoneName` chain member** (21 occurrences, found by Sharko's second pass):
  a getter used as a chain link, no schema entry warranted. Ticket 02's net will list it; it should
  be excluded by name there rather than silently skipped.
- **`airwave_zones`** scores 7 carried / 1 ignored, and its single gap (`setOnWon`) is already a
  declared loss through `callback_hints`. Nothing to do — recorded because it is the measurement
  that proves this is concentrated in `combat_zones:` rather than a general schema limitation.
- **Settings absent from Sharko's corpus.** He was explicit that he measured the scalar keys his
  campaigns use, not everything `missionConfig.lua` can carry. Ticket 02 is the answer to that
  unknown: a net does not need the list in advance.

## David's arbitrations, 2026-08-17

- **Report *and* carry.** Ticket 02 (declare the losses) ships first as the instrument, then 03 and
  04 carry every key — not a chosen subset. All fourteen scalars are in scope.
- **Passwords belong in `mission.yaml`**, and always have: `security.password_hashes:` exists and is
  documented at `lua_config_generator.py:202`. The first draft of ticket 04 treated their
  destination as an open question; that was wrong and the ticket is rewritten. `veaf-pilots.txt`
  carries pilots (UCID + level), never passwords. The real trap is the opposite one and is now the
  ticket's main warning: the framework's own **public** hashes must be *skipped* by the extractor,
  or a conversion re-opens the hole `SECREV-2 / VMR-040` closed.
- **We write the code.** Sharko offered a PR twice; we take it instead. His two harnesses stay the
  acceptance test.

## Definition of done

- [x] A multi-line `setBriefing` no longer truncates its chain — the walker now carries paren
      depth between lines, so a concatenated *or* `[[long]]` argument keeps the chain open
- [x] A converted mission that loses a setting **says so** — in the report and in the generated Lua
- [x] `completable` survives a v5 → v6 conversion (the asymmetry closed on the extraction side)
- [x] The six `combat_zones` setters carried
- [x] Every scalar lands in `mission.yaml` via `module_settings:` — generic rather than fourteen
      named keys, so a setting nobody enumerated is carried too; what remains (tables, functions)
      is named in the report
- [x] A v5 mission carrying the shipped `PASSWORD_L0` / `PASSWORD_L1` hashes converts **without**
      copying them into its own `password_hashes:`
- [x] `import ConfigMigrator` no longer loads pydantic — and the cause was **neither** the one
      reported nor the one first measured: the chain through `lua_config_generator` was real but
      secondary, and `mission_builder/__init__.py` importing the whole package was what dominated.
      Found with `-X importtime`, fixed by making the package lazy (PEP 562)
- [x] Coverage gate: 81.9% measured against a gate of 81, inside the ~2-point rule
- [ ] Sharko's two harnesses re-run against the result — his numbers are the acceptance test.
      **Left open on purpose**: no test here can produce them, and he answered on all three issues.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a v5 mission converted to v6 behaves differently and nothing says which settings stopped applying.** Sharko's #722/#723/#725, opened as a lot by `CHORE-GITHUB-ISSUE-TRIAGE` which found nothing tracking them. Three surfaces, one failure mode: the chain walker stops at any line not starting with `:`, so a multi-line `setBriefing` **truncates the chain** and drops every setter after it — **302 briefings of 1864**, worst case 137 characters migrated as **6**; six `combat_zones` setters have no schema key at all (0 occurrences each in the migrator against 5 for the control `setBriefing`), used on **1135 zones** apiece and always to turn something **off**, so losing them *inverts* the behaviour rather than neutralising it; and **14 of 28 scalar keys** vanish, security passwords and IADS timing included. Each claim re-verified here against `4b0c4d55` rather than taken from the reports — including the one the reports did not spell out: the information **already exists on another path**, since `migrate-config` writes the migrated buffer where unrecognised lines survive as comments while `convert-v5` generates a 349-byte header and deletes the original, as its own comment admits. Hence the order — the declared-loss net (ticket 02, copying the `callback_hints` precedent) ships **before** the schema keys, because the list it prints *is* the work list for 03 and 04 and shrinks as they land. `completable` is the cheapest real win: the emitter exists at `lua_config_generator.py:656`, only extraction is missing, and without it 82 narrative zones self-complete ~60 s in and chain onward — a campaign break, not a glitch. David's arbitration: **report *and* carry**, all fourteen scalars, and we write the code rather than take Sharko's offered PR — his harnesses stay the acceptance test. His password finding was re-investigated on David's correction and **inverted**: `security.password_hashes:` has always been the home for a mission's SHA hashes and `veaf-pilots.txt` never held one, so the danger is not a homeless secret but the reverse — `veafSecurity.lua` ships two hashes **common to every mission in a public repo**, `VMR-040` closed that by clearing the tables, and an extractor copying a v5 `PASSWORD_L1` without checking its value would carry the public hash into the mission's own list and re-open it. Also: reassigning that constant never did anything in v5 (the table is filled at module load, before the mission config runs), so the pattern to extract is `password_L1["<hash>"] = true`, mirroring the `password_MM` rule that has existed all along  — David's call: **we write the code**, and all three issues got a circumstantiated reply. **All five tickets shipped 2026-08-17.** Two findings the tickets did not predict: the generic `module_settings:` carrier replaced fourteen named keys, because the fourteen were measured on one corpus and named keys would leave the next fourteen to be found the same way; and ticket 05's cause was **neither** the one reported nor the one I first measured — the chain through `lua_config_generator` was real but secondary, while `mission_builder/__init__.py` importing the whole package dominated, found only with `-X importtime` and fixed by making the package lazy (PEP 562). Three existing tests were **repointed rather than repaired**: they used a scalar as their example of a *lost* setting, which ticket 04 now carries — the failure was the previous ticket succeeding

## Tickets, in full

## 01 — The chain walker accepts string continuations

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issue: [#722](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/722) · Type: fix ·
File: `src/python/veaf-tools/mission_builder/config_migrator.py`

### The defect

`ConfigMigrator._local_zone_chain_end()` walks a `VeafCombatZone` builder chain by accepting only
lines whose stripped form starts with `:` (`config_migrator.py:1404-1411`, verified 2026-08-17):

```python
if content[pos + 1 : line_end].lstrip().startswith(":"):
    pos = line_end
    ...
else:
    break
```

A Lua string concatenation continues on a line starting with `"` (or `'`, `..`, `[[`), so a
multi-line `setBriefing(...)` **ends the chain**. Everything after it is dropped from
`combat_zones:` — the loss is **positional, not setter-specific**.

### Reproduction (Sharko's, re-usable as the test)

```lua
local ZoneCZ = VeafCombatZone:new()
    :setMissionEditorZoneName("CombatZone_Example")
    :setBriefing("first line\n" ..
        "second line\n")
    :setTraining(false)
    :initialize()
```

`_extract_combat_zones()` yields `['briefing', 'type', 'zone_name']` — `training` gone, `briefing`
holding only the first fragment. The same chain on one line yields `training` too, which is what
isolates the defect to the multi-line form.

### Scale

302 truncated briefings out of 1864 zones. Worst case: **137 characters migrated as 6**
(`CombatZone_MOA2-Hawash`). A briefing is player-facing text, so a truncated one ships an
incomplete mission description.

### What to do

Continue the walk on a line that is a chain link **or** a string continuation, and stop only on a
line that is neither. Do not try to parse Lua: the walker's job is to find where the chain ends,
and treating a leading `"`, `'`, `..` or `[[` as "still inside the previous call" is enough.

Watch the case Sharko's example carries: the closing `)` of `setBriefing` sits on the continuation
line, so the parser that reads the setter's argument must also see the joined text, not just the
first fragment. A walker fix that widens the chain but leaves `briefing` at 6 characters solves
half the ticket.

### Tests

- The multi-line chain above extracts **both** `training` and the full two-line briefing
- The single-line equivalent keeps extracting what it extracts today (no regression)
- A chain followed by unrelated code still ends where it ends: a line starting with `local`,
  `end` or a comment must **not** be swallowed as a continuation
- A `[[long bracket]]` briefing spanning lines
- Assert on the briefing's **length or content**, not merely on the key being present — the
  original defect produced a `briefing` key that was there and wrong, which is the shape a
  key-presence assertion misses

## 02 — Declare the settings that are not migrated

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issues: [#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) (option 2),
[#723](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/723) (option 2) · Type: feat ·
Files: `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`

### Why this is the ticket that matters

`convert-v5` generates `mission-script.lua` from scratch and deletes `missionConfig.lua`
(`v5_converter.py:1144-1151`). No `warning` is emitted for a setting no extractor recognised —
**by construction, you cannot report what you do not see**. So the failure mode is a mission that
looks converted, behaves differently, and names nothing.

The information already exists on another path, which is the argument for doing this rather than
chasing keys one by one: the **migrated buffer** keeps unrecognised lines as commented-out code,
and the standalone `migrate-config` command writes it. `convert-v5` throws it away — the comment at
`v5_converter.py:1153-1158` says exactly that. We are not missing the data; we are discarding it on
the path everybody uses.

### The precedent to copy

`MigrationResult.callback_hints` (`config_migrator.py:92`) already models a **declared loss**:
Lua snippets for callbacks that must be set by hand, emitted into the generated file as
`-- [v6 migration] callbacks not migrated. Set them manually after init:` (`:1637`). `setOnWon` on
`airwave_zones` is handled this way today and nobody complains, because the author is told.

### What to do

In `pre_extract`, after the extractors have run, collect every remaining top-level assignment whose
target matches a known VEAF module table (`veaf*.`, `ctld.`, `csar.`) and that no extractor
consumed, into a `not_migrated` list on `MigrationResult`. Report it the way `callback_hints` is
reported:

- a `warning` naming each dropped setting (so it lands in `convert-v5-report.md`)
- a commented block in the generated `mission-script.lua`, carrying the **original line** so the
  author can paste it back

Do the same for builder-chain setters that no `_parse_*` maps to a key — that is #723's cheap half,
and it covers the seven ignored `combat_zones` setters before ticket 03 carries any of them.

### Two traps

- **Do not report what is deliberately not carried.** `getMissionEditorZoneName` (21 occurrences)
  is a getter used as a chain link, and the `ctld.*` / `csar.*` keys are already handled generically
  by `_extract_ctld_csar`. An exclusion list by name, with a comment per entry saying why — a net
  that cries wolf gets muted, and then it is worth nothing.
- **A silent no-op looks identical to a clean result.** Sharko's harnesses run two witnesses on
  every execution for exactly this reason. Do the same here: a test asserting a **known-dropped**
  key is reported, and one asserting an injected dummy key is *not* (it belongs to no VEAF table).

### Tests

- A `missionConfig.lua` carrying `veafSkynet.DelayForStartup = 150` produces a warning naming it and
  a line in the generated Lua
- A key an extractor *does* consume (`veaf.config.MISSION_NAME`) is **not** reported — the witness
  that proves the net discriminates
- An unknown non-VEAF assignment is ignored
- `getMissionEditorZoneName` in a chain is not reported
- The generated `mission-script.lua` is no longer a 349-byte header when something was dropped

## 03 — Carry the missing `combat_zones:` keys

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issue: [#723](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/723) · Type: feat ·
Files: `mission_builder/config_migrator.py` (`_parse_combat_zone`),
`veaf_libs/lua_config_generator.py` (`_emit_combat_zone_def`), `src/defaults/mission-folder/mission.yaml`

### The gap, verified here 2026-08-17

Six `VeafCombatZone` setters the runtime supports have **no key** in the `combat_zones:` schema —
each of them scores **0 occurrences** in `config_migrator.py`, against 5 for the control
`setBriefing`:

| Setter | Zones using it (Sharko's corpus) | Framework default |
|--------|----------------------------------|-------------------|
| `setCompletable` | 82 | `true` |
| `setShowUnitsList` | 1135 | `true` |
| `setShowZonePositionInfo` | 1135 | `true` |
| `setEnableUserActivation` | 1135 | `true` |
| `setEnableSmokeAndFlare` | 1135 | `true` |
| `disableRadioMenu` | 171 | menu enabled |

All of them are used to turn a feature **off**, and every default is `true` — so losing one does not
fall back to something neutral, it **inverts the behaviour**.

### Start with `completable`, because half of it already exists

`lua_config_generator.py:656` already emits it:

```python
if zone_def.get("completable", True) is False:
```

and `setCompletable` appears nowhere in the migrator. So the round-trip is **asymmetric**: a
hand-written `mission.yaml` can express it, a converted one never will. Closing that costs the
extraction side only — the emitter is written, tested and shipped (it came from
`FEAT-ACTIVATION-CONTROLS`).

It is also the one with real consequences. Without `completable: false`, `isCompletable()` lets
`scheduleWatchdogFunction()` arm; a zone that spawns no RED unit is deactivated at the first
watchdog tick (~60 s after activation), broadcasts "all enemies destroyed" and calls
`activateNextChainedZone()`. On 82 narrative or support zones that is a **campaign progression
break**. `disableRadioMenu` is the second worst: 171 zones that were hidden on purpose reappear in
the F10 menu, wearing the placeholder names their authors gave them *because* nobody was meant to
see them.

### What to do

Extraction in `_parse_combat_zone`, emission in `_emit_combat_zone_def` for the five that have no
emitter yet, and the keys documented on the combat-zone reference page **in both languages**.

Per the defaults-lockstep rule (`CLAUDE.md` §9.7), if the generated `mission.yaml` shape changes,
`src/defaults/mission-folder/mission.yaml` moves in the same lot.

Name the YAML keys after what they do, not after the Lua setter: the reader of a `mission.yaml` is a
mission maker, not someone who has read `veafCombatZone.lua`. Follow whatever `completable` set as
precedent rather than inventing a second convention.

### Tests

- Each setter, in a real builder chain, produces its key — and **removing the setter removes the
  key**, which is the shape of assertion Sharko's harness uses and the only one that catches an
  extractor keying on the wrong thing
- Round-trip: a v5 chain with `setCompletable(false)` converts to `completable: false` and generates
  Lua that turns it off — the asymmetry closed on both sides at once
- A zone with none of them keeps generating exactly what it generates today (the defaults are
  `true`, so an emitted `true` would be noise in every existing mission)

## 04 — Carry the fourteen dropped scalars

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issue: [#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) (option 1) ·
Type: feat · Files: `mission_builder/config_migrator.py`, `veaf_libs/lua_config_generator.py`

David's call 2026-08-17: **report *and* implement** — ticket 02 makes every loss visible, this
ticket carries all fourteen keys rather than a chosen subset.

### The fourteen

**Security** — `veafSecurity.PASSWORD_L1`, `veafSecurity.password_L1`, `veafSecurity.authenticated`,
`veafCarrierOperations.DisableSecurity`.
**IADS** — `veafSkynet.DelayForStartup` (150 in Sharko's missions), `veafSkynet.DynamicSpawn`,
`veafSkynet.PointDefenceMode`.
**The rest** — `veafRadio.RadioMenuName` (`"BFR"`, player-visible), `veafRadio.radioMenu.title`,
`veafCombatZone.HideZoneNameFromGroupNames`, `veafSpawn.HideRadioMenu`,
`veaf.DEFAULT_GROUND_SPEED_KPH` (25), `veaf.DO_NOT_EXPORT_JSON_FILES`, `veaf.config.ww2`.

### Passwords: the destination exists, and porting them naively re-opens a security hole

Verified 2026-08-17, and it corrects the first draft of this ticket.

`mission.yaml` **already carries mission passwords**: `security.password_hashes:`, documented at
`lua_config_generator.py:202` as *"add SHA-1 hashes to restrict access"*, emitted at `:1432-1434`.
`veaf-pilots.txt` holds no password at all — it identifies pilots by UCID and level, and is where
the ADMIN tier comes from. So there is no question of where a hash goes: `security.password_hashes`,
same as `password_MM` already does through `security.password_mm_hashes`.

Two things make the extraction non-obvious:

- **`veafSecurity.lua:156-159` ships `PASSWORD_L0`/`PASSWORD_L1` hashes common to every mission, in
  a public repository.** `SECREV-2 / VMR-040` closed that: when a mission declares its own hashes,
  the generator writes `password_L0 = {}` / `password_L1 = {}` / `password_L9 = {}` **before**
  adding them, so the well-known password stops opening the mission. An extractor that copies a v5
  `PASSWORD_L1` into `password_hashes:` without checking its value will happily carry the **shipped
  public hash** into the mission's own list — and re-open exactly what VMR-040 closed. The two
  framework hashes must be recognised and **skipped**, not migrated.
- **Reassigning `veafSecurity.PASSWORD_L1` alone did nothing in v5.** `password_L1[PASSWORD_L1] =
  true` runs at module load, before the mission config executes, so a later reassignment of the
  constant never reached the table. What actually set a mission password is the pair
  `password_L1 = {}` then `password_L1["<hash>"] = true` — which is why Sharko measured *both* keys
  as lost. **Extract that pattern**, not the constant: a regex on
  `veafSecurity\.password_L1\s*\[\s*"([^"]+)"\s*\]`, mirroring `_PASSWORD_MM_RE`
  (`config_migrator.py:1789`), which has done this for `password_MM` all along.

`veafSecurity.authenticated` is runtime state, not configuration (`veafSecurity.lua:162` sets it at
load and `initialize()` sets it again). It gets no schema key — report it through ticket 02's
declared-loss list, and say so there rather than letting it fall in the gap.

### IADS

`_SKYNET_INIT_RE` (`config_migrator.py:743`) matches only the **call**
`veafSkynet.initialize(bool, bool, bool, bool)`. `DelayForStartup`, `DynamicSpawn` and
`PointDefenceMode` have no YAML key at all, so a mission that tuned its IADS loses the tuning with
no symptom that points back at the conversion.

### One gain to preserve

Sharko noticed between his two runs that `veaf.SecurityDisabled` now reaches `mission.yaml`, as a
side effect of `fix(security): honour the retired SecurityDisabled spelling` in 6.14.0. Pin it with
a test so this ticket cannot undo it.

### Tests

- Each of the fourteen keys converts to a `mission.yaml` entry and generates Lua that applies it —
  except `veafSecurity.authenticated`, asserted to appear in ticket 02's declared-loss output
- **A v5 config carrying the shipped `PASSWORD_L1` hash (`bdc82f5e…`) produces no
  `password_hashes:` entry** — the regression test for the VMR-040 hole. Same for `PASSWORD_L0`
  (`47c7808d…`)
- A v5 config carrying a *custom* hash in `password_L1["…"]` produces it in `password_hashes:`, and
  the generated Lua clears the tables before adding it
- `veaf.SecurityDisabled` keeps surviving
- Between this ticket and 02, the fourteen are all accounted for — a test enumerating them and
  asserting each is either carried or reported, so none falls in the gap

## 05 — Stop pulling pydantic into the migrator

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issue: [#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) (Sharko's closing
note) · Type: refactor · File: `src/python/veaf-tools/veaf_libs/lua_config_generator.py`

### Measured, not deduced

```
$ python -c "import sys; from mission_builder.config_migrator import ConfigMigrator; \
             print('pydantic loaded:', 'pydantic' in sys.modules)"
pydantic loaded: True
```

The chain: `config_migrator.py:19` imports `veaf_libs.lua_config_generator`, which at `:28` imports
`veaf_libs.checklists`, which at `:29` imports pydantic. Since 6.14.0, importing the **config
migrator** loads the **guided-checklist model**.

Note that `config_migrator` does not import `checklists` itself — a grep of its imports says
`i18n`, `lua_config_generator`, `lua_module_scanner` and nothing else, which is why the report's
phrasing ("the migrator imports `veaf_libs.checklists`") reads as wrong until you follow the second
hop. The coupling is real; it just lives one level down.

### Why bother

Inside the packaged environment this costs nothing — pydantic is a project dependency. It costs
someone importing `ConfigMigrator` as a library, where `typer` + `pyyaml` used to be enough. That
someone is Sharko, whose two measurement harnesses are the acceptance test for this whole lot, and
more generally anyone building tooling on our converter. A cockpit-checklist model has no business
being on that path.

### What to do

`config_migrator` needs exactly one thing from `lua_config_generator`: `yaml_module_entry`. Two
routes, pick by looking at the file:

- defer `lua_config_generator`'s `checklists` import into the function(s) that use it, or
- move `yaml_module_entry` to a module that carries no heavy dependency.

The second is cleaner if `yaml_module_entry` is a small formatting helper — check what else imports
it before moving it, since the win is not worth breaking three call sites.

### Test

A test asserting `pydantic` is **absent** from `sys.modules` after importing `ConfigMigrator`, run
in a fresh interpreter — a test that imports it in a process where something else already pulled
pydantic in passes for the wrong reason and would pin nothing. `subprocess` with `-c`, asserting on
the exit code, is the honest form.
