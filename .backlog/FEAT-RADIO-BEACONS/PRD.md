# FEAT-RADIO-BEACONS — no VEAF command spawns a radio beacon

Status: ⬜ ready

Origin: [#38](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/38) (FM beacons) and
[#192](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/192) (`-beacon` through CTLD) —
same mechanism, and #192 already points at the implementation.

## The gap

No VEAF beacon command exists. `ctld.spawnRadioBeaconUnit` is *mentioned* at `veafGrass.lua:1349` as
having **no public equivalent**, which is exactly the hole both issues describe. `-tacan` exists and
is the model #192 names.

## Scope

A `-beacon` marker command on the `-tacan` model, spawning through CTLD 2 — which is now properly
initialised (`FIX-CTLD-NEVER-INITIALIZED`), so the dependency is sound in a way it was not when #192
was filed.

**Settle one thing first**: whether CTLD 2 still exposes beacon spawning the way CTLD 1 did. That
comment in `veafGrass.lua` predates the CTLD 2 migration and may describe a world that no longer
exists — the same trap that made #72's first verdict wrong.

## The open question, settled — 2026-08-24

**CTLD 2 exposes beacon spawning better than CTLD 1 did, and for exactly this use case.** The lot
proceeds as written; nothing needs re-scoping.

`ctld.spawnRadioBeaconUnit` is gone — zero occurrences in the vendored `CTLD.lua` (`2.0.0-rc7`,
`verbatim`). What replaced it is a purpose-built public method:

```lua
CTLDBeaconManager:createAtPoint(point, coalitionId, countryId, opts)   -- CTLD.lua:18693
```

- `point` is a world vec3, used **as given**, no offset. `coalitionId` / `countryId` are numbers.
- `opts`: `name`, `batteryMinutes` (`-1` never expires; default 30), `isFOB`.
- Returns a beacon whose `.vhf` / `.uhf` / `.fm` are frequencies **in Hz**, or nil on spawn failure.
- Needs **no unit, no transport, no zone and no player** — that is the whole difference from `dropBeacon`.
  It spawns its own three `TACAN_beacon` groups.

**FM is answered, unconditionally**: every beacon is three beacons, VHF + UHF + **FM**
(`CTLD.lua:18703-18705`), the FM one transmitting with `mode = 1`. That is #38's ask, for free.

**The one real constraint, and it changes the scope**: the frequency is **drawn at random** from internal
pools (`_pickFreq`, `CTLD.lua:18561-18570`) and there is no parameter, public or private, to request a
specific one. So the command can guarantee *"an FM beacon exists, here are its three frequencies"* but
**cannot** honour a `freq 40.5` option without a change to CTLD itself. Decide that here rather than
discovering it mid-implementation.

`removeBeacon(name)` exists (`CTLD.lua:18815`), so an erase counterpart is nearly free if wanted.

### The `veafGrass.lua` comment was not the stale part — this PRD's reading of it was

The comments live at `veafGrass.lua:1344` and `:1818` (the `:1349` this PRD cited is a copy in a
`.claude/worktrees/` checkout). Read in place they are **accurate**: they document
`veafGrass.spawnTacanCarrierUnit` and say CTLD 1's low-level *single-unit* spawner has no public CTLD 2
equivalent — which is true, `_spawnBeaconUnit` is private. They never claimed beacon spawning was gone.
And the repository already held the answer: `.backlog/archive/FEAT-CTLD2-INTEGRATION.md:325` records the
migration row `spawnRadioBeaconUnit + createRadioBeacon → CTLDBeaconManager…createAtPoint`.

### Implementation is cheaper than expected

- VEAF **already calls** `createAtPoint` twice: the FARP beacon (`veafGrass.lua:1829`) and the FOB beacon
  (`veafSpawnGround.lua:205`), both formatting `"ADF : %.2f KHz - %.2f MHz - %.2f MHz FM - %s"`. Copy that.
- The guard is `veaf.isCtldReady()` (`veaf.lua:5472`).
- `test/lua/dcs_mocks.lua:797-804` already mocks `CTLDBeaconManager` with `createAtPoint` **and**
  `removeBeacon`, reset between tests. No new plumbing for the tests.

### Decided — 2026-08-24

**The frequency stays as CTLD gives it, and the request goes upstream** (David): a PR on
`VEAF/CTLD` asking for a way to request a frequency or a band, rather than a VEAF-side workaround. So
this lot ships `-beacon` **without** a `freq` option, reports the three frequencies CTLD drew, and the
option arrives later through the vendored update — which is the honest order, since faking a choice VEAF
cannot make would be a command that lies.

### But `-tacan` is a poor model for one thing: reporting

`-tacan` tells the player **nothing**. It has no message of its own and falls through to
`spawn.unit_spawned`, which names the unit and the country and never the channel or band — and it does
not even emit that, because the alias sets `setBypassSecurity(true)` and the handler passes
`bypassSecurity` into `spawnUnit`'s `silent` parameter (`veafSpawnAircraft.lua:1441` against the signature
at `:29-44`). Filed separately as
[`FIX-SPAWN-BYPASSSECURITY-AS-SILENT`](../FIX-SPAWN-BYPASSSECURITY-AS-SILENT/PRD.md).

So the beacon command needs **its own** i18n key formatting all three frequencies, and must not inherit
that wiring. Handing a pilot a beacon without telling him its frequencies would make the command useless.

Also: `_spawn tacan` is documented **nowhere** (only the `-tacan` alias appears, in `doc/ALIASES.md`), so
there is no section to mirror — the documentation is greenfield in both languages.

## Definition of done

- [ ] A marker command spawns a radio beacon, FM included (#38's ask)
- [ ] CTLD 2's real beacon API checked rather than inferred from a stale comment
- [ ] Documented on the spawn page, both languages
