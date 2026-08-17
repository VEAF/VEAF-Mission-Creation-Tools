# FIX-CONVERT-V5-SILENT-LOSSES — what `convert-v5` drops without saying so

Status: ⬜ ready

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
| 01 | [The chain walker accepts string continuations](tickets/01-chain-walker-string-continuation.md) | #722 |
| 02 | [Declare the settings that are not migrated](tickets/02-declare-unmigrated-settings.md) | #725, #723 |
| 03 | [Carry the missing `combat_zones:` keys](tickets/03-combat-zones-schema-keys.md) | #723 |
| 04 | [Carry the fourteen dropped scalars](tickets/04-security-skynet-scalars.md) | #725 |
| 05 | [Stop pulling pydantic into the migrator](tickets/05-decouple-migrator-pydantic.md) | #725 (comment) |

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

- [ ] A multi-line `setBriefing` no longer truncates its chain, with a regression test on the
      multi-line form
- [ ] A converted mission that loses a setting **says so** — in the report and in the generated Lua
- [ ] `completable` survives a v5 → v6 conversion (the asymmetry closed on the extraction side)
- [ ] The six `combat_zones` setters carried
- [ ] The fourteen scalars each either land in `mission.yaml` or are named in the report, with a
      test enumerating them so none falls in the gap
- [ ] A v5 mission carrying the shipped `PASSWORD_L0` / `PASSWORD_L1` hashes converts **without**
      copying them into its own `password_hashes:`
- [ ] `import ConfigMigrator` no longer loads pydantic
- [ ] Coverage gate raised, per the ratchet policy
- [ ] Sharko's two harnesses re-run against the result — his numbers are the acceptance test
