# FEAT-RADIO-BEACONS — no VEAF command spawns a radio beacon

Status: ✅ done

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

### The upstream request is filed — 2026-08-24

[`VEAF/CTLD#128`](https://github.com/VEAF/CTLD/pull/128) adds `opts.frequencies` to `createAtPoint`: an
optional subset of `{ vhfKHz, uhfMHz, fmMHz }`, bands left out still random, every existing caller
untouched. Refusals are total — `nil, reason`, nothing spawned, no frequency consumed — because falling
back to a random pick is the one failure nobody can see: the kneeboard still says 250 kHz, the pilot
tunes 250 kHz and hears silence.

**This lot does not wait for it.** `-beacon` ships reporting the three frequencies CTLD drew; the option
arrives later through a vendored update, and only then is a `freq` parameter worth adding here.

Two things that came out of building it, both relevant to this lot:

- **A pre-existing CTLD bug fixed there**: `createAtPoint` drew its frequencies before spawning and never
  gave them back on spawn failure. Invisible while everything was random.
- **The FM pool holds only 300 of the 460 possible 100-kHz steps** between 30.0 and 75.9 MHz — gaps at
  36.0–39.9, 46.0–49.9, 56.0–59.9 and 66.0–69.9, measured from the generator. So briefing 38.00 MHz, an
  ordinary FM frequency, is refused. That is a property of the pool rather than of the new option, and
  widening it would change every existing random draw, so it is asked separately as
  [`VEAF/CTLD#127`](https://github.com/VEAF/CTLD/issues/127). If those gaps turn out to be accidental,
  closing it makes the option strictly more useful with no further work.

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

## Delivered — 2026-08-24

`_spawn beacon`, with the alias `-beacon`. One command places **three** beacons at the marker — ADF
(VHF), UHF and **FM** — which answers #38's FM ask without an option, because CTLD lights all three
whether you want them or not.

**Placed exactly where the marker was dropped**, `radius` defaulting to 0. Every group-spawning command
scatters; a beacon's position is the reason for dropping it there.

**The message is the feature**, and it is the one thing `-tacan` was not copied for. CTLD draws each
frequency from an internal pool and exposes no way to request one, so the command's whole job is to
report what it got:

```
Radio beacon up — ADF 245.00 kHz · UHF 251.00 MHz · FM 40.50 MHz
```

`-tacan` emits nothing at all — no message of its own, and none of its i18n keys carry a frequency — so
copying its reporting would have shipped a command that works and cannot be used. The handler passes
`options.silent` rather than `bypassSecurity` into the silent slot, which is what makes `-tacan` mute;
see [`FIX-SPAWN-BYPASSSECURITY-AS-SILENT`](../FIX-SPAWN-BYPASSSECURITY-AS-SILENT/PRD.md).

**The handler returns nil, deliberately.** The dispatcher reads a handler's return as a *group name* and
then runs its own post-processing on it — alarm state, MFD hiding, platform registration. A beacon is
three groups with CTLD's battery timer, removal and map layer on top; handing it one of them would let
VEAF reconfigure what it does not own. A test pins that.

**Two refusals rather than silence.** No CTLD started (the state a mission built before
`FIX-CTLD-NEVER-INITIALIZED` is in) and a `createAtPoint` that returns nil both tell the player. He
dropped a marker and is waiting for something; saying nothing is the worst of the three outcomes, and
reporting success on a failed spawn would leave him tuning a frequency nothing transmits on.

**A false alarm checked before it was reported.** The existing FOB beacon passes a *country name string*
where `createAtPoint` documents a `countryId` number. Read through: `ctld.utils.dynAdd` resolves either a
name or an id (`CTLD.lua:5290-5311`), so the existing call is correct and this one passes a name too,
consistent with its neighbour.

**16 Lua tests** across `test_veafSpawn.lua` (behaviour) and `test_veafSpawnParser.lua` (the descriptor),
and four mutations run against them: dropping the frequencies from the message kills 2, removing the
CTLD-not-ready guard kills 1, returning a group name kills 1, dropping `radius = 0` kills 1. One of those
mutations was written wrong first — a `return` followed by a comment, which Lua 5.1 refuses — and produced
an empty result rather than a pass; re-run properly it killed its test.

Documented on the spawn page under `{#beacon}` in both languages, with the option table and why the
frequency is CTLD's choice, and listed in both alias tables.

## Definition of done

- [x] A marker command spawns a radio beacon, FM included (#38's ask) — all three bands, always
- [x] CTLD 2's real beacon API checked rather than inferred from a stale comment — and the comment turned
      out to be accurate while the PRD's reading of it was the error
- [x] Documented on the spawn page, both languages, plus both alias tables
