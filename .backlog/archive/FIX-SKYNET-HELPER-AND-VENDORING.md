# FIX-SKYNET-HELPER-AND-VENDORING — the VMCT half of The Reaper's report

Status: ✅ done — 2026-10-04. Ticket 03's in-game reading is no longer owed: check 13 of · archived 2026-11-24
`verify-mission-c` cannot discriminate any more (`FEAT-SPOTTER-DEMO-MISSION` ticket 04) and its
question moved to that lot's ticket 05; Skynet 3.5.0 itself was seen running in game on 2026-10-03
(R1, R13).

Origin: The Reaper, 2026-09-17, on a mission built with veaf-tools:

> *"J'ai configuré Skynet sur une mission avec les outils VEAF. J'ai un problème, quand il y a des
> EWR rouge à portée, les SAM ne s'allument pas même si on est à portée voire très proche. Quand il
> n'y a plus d'EWR rouge, les SAM deviennent autonomes et actifs."*

Mission `VEAF_OpenTraining_Caucasus_v6_20260917_debug_skynet_1705.miz`, same `dcs.log` as the CTLD
report of the same evening.

## Read this first: the work is split across two repositories

**Skynet is maintained by VEAF**, in [`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS) — the
Regroupement's repository is read-only and walder has been inactive for years. That repository has
separate sources (`skynet-iads-source/*.lua`), its own build and its own test suite; the
`src/scripts/community/skynet-iads-compiled.lua` carried here is the **build artifact**, and editing
it directly would be lost at the next build.

So the fix itself — the last line of defense, and the coverage refresh — lives in the Skynet
repository, in its `FEAT-LAST-LINE-OF-DEFENSE` lot. **This lot is the VMCT half only**: what belongs
to `veafSkynetIadsHelper.lua`, the documentation, and bringing the new Skynet version in.

## What was found, in one page

A SAM held by the network has its emission switched off, so it is blind: it only lights up when an
EWR **that covers it** hands it a contact. Fly under the EWRs' horizon and nothing reacts, whatever
the distance. Kill the EWRs and the sites revert to the DCS AI, which lights everything up — hence
the inversion the reporter describes.

Measured on his log, 24 minutes of 5 s cycles: **7 933** SAM status lines dark under network control,
**zero** ever lit, the only two active sites being the pair that had no EWR parent. Stated honestly:
the closest contact to any network EWR in that log is 51.85 NM, so his own close pass is not in this
log — the mechanism is proven from the code, not from this measurement.

Settled with Flogas and the historical IADS developers on 2026-09-19, then grilled on the design the
same day. The full decision record lives in the Skynet lot; what matters here is that the fix exists
elsewhere and this lot carries its consequences on the VMCT side.

## Tickets

| # | Ticket | State |
|---|---|---|
| 01 | [Remove the two dead `actAsEW` reset blocks](FIX-SKYNET-HELPER-AND-VENDORING.md) | ✅ done |
| 02 | [Document what a network SAM does and does not see](FIX-SKYNET-HELPER-AND-VENDORING.md) | ✅ done |
| 03 | [Vendor the new Skynet version](FIX-SKYNET-HELPER-AND-VENDORING.md) | 🧑 vendored; the in-game reading is owed |
| 04 | [Repair the Skynet drift watch, which can no longer fire](FIX-SKYNET-HELPER-AND-VENDORING.md) | ✅ done |

The lot ships as **one PR**, once the Skynet side is released. Ticket 01 is independent and could go
first, but David chose a single PR per repository on 2026-09-19.

## The blocker is lifted — 2026-09-21

[**Skynet 3.5.0**](https://github.com/VEAF/Skynet-IADS/releases/tag/v3.5.0) is published, the first
release under joint VEAF / Regroupement de Patrouilles (BFR, NAWACS) maintenance. It carries the last
line of defense and the coverage refresh this lot was waiting for, plus three coverage fixes that are
not in the artifact carried here, and `SkynetIADS:reportContact` — which is what
[`FEAT-SPOTTER-NETWORK`](FEAT-SPOTTER-NETWORK.md) needs to close its in-game check.

The release itself is a **downloadable asset**, so vendoring no longer means recompiling from
sources. That, and the fact that the drift watch pointed at a file this repository no longer commits,
is what ticket 04 is about — read it before touching `vendored.yaml`.

## Definition of done

- [x] The five-NATO-name `actAsEW` resets are gone, and an explicit EW-watch request survives any
      group joining the network — `TestVeafSkynetEwrWatchSurvives`, which was checked to fail on the
      code as it stood.
- [x] `mission.yaml` carries the new SKYNET keys, and `src/defaults/mission-folder/mission.yaml` is
      aligned in the same lot (CLAUDE.md §9.7).
- [x] Both documentation languages updated, `poetry run docs-check` green.
- [x] The vendored artifact is **executed** against the DCS mocks, not merely loaded —
      `test_community_scripts_load.lua`. Parsing a file says nothing about a main chunk that raises,
      which is exactly what let CTLD rc8 through and killed every radio menu (#957).
- [x] `poetry run test-lua` green (49 suites).
- [ ] The in-game reading of ticket 03, which also closes `FEAT-SPOTTER-NETWORK`. **Needs DCS.**

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the VMCT half of The Reaper's report of 2026-09-17.** A SAM held by the network has its emission cut, so it only lights up when an EWR that covers it hands it a contact: fly under their horizon and nothing reacts, kill them and everything reverts to the DCS AI and engages. Measured on his log: 7 933 SAM status lines dark, **zero** ever lit in 24 minutes. The fix itself lives in VEAF/Skynet-IADS, which VEAF now maintains — this lot carries the VMCT side: removing two dead actAsEW reset blocks left over from a behaviour dropped in 2022, the documentation of what a network SAM actually sees, and vendoring the new Skynet version with its month of upstream work. **Unblocked 2026-09-21**: [Skynet 3.5.0](https://github.com/VEAF/Skynet-IADS/releases/tag/v3.5.0) is released, and a fourth ticket was added for a drift watch that can no longer fire — it points at the artifact Skynet stopped committing, so its `drifted` reading is the file's own deletion and the next release would pass unnoticed. **Built 2026-09-21**: both sweeps gone with a test that fails on the old code, 3.5.0 vendored from the release asset (the `stylua` pass earns its keep — 843 changed lines against 9 085 raw), five new `modules.SKYNET` keys for the last line of defence, the documentation of what a network SAM actually sees in both languages, and the watch moved to GitHub releases and proved able to fire. Only the in-game reading is left, and it needs DCS

## Tickets, in full

## 01 — Remove the two dead `actAsEW` reset blocks

Status: ✅ done

### Decision

Settled with Flogas, 2026-09-19: **the two blocks are useless, remove them and clean up around
them.**

### The history, which is what makes them useless

At the start, VEAF forced the large systems into EW-watch mode — they watched permanently and saw
for themselves. A block was then added so that when a **real** EWR joined the network after
start-up, those large systems dropped their watch duty: with a proper radar on station they no
longer needed to do the job themselves. It sat at the end of the network-initialisation block, and
a twin was placed in the per-group path.

Then the forcing was dropped. `a68dfd32` (2022-04-05, *"IADS: removed defaulting to EWR for SAM
sites"*) **flipped both blocks from `true` to `false`** rather than deleting them, adding `Mcc-sr`
false, `SA-5` false and `Ewr` true; `7ead5793` (2022-05-20) removed `Mcc-sr` and `Ewr`. Flogas
carried the list forward in `3002aaad` (2023) and `d4e1b66c` (2024).

Since nothing forces the watch on anymore, telling those five types to drop it asks for something
that is already true: Skynet builds every radar element with `instance.actAsEW = false`
(`skynet-iads-compiled.lua:2585`). The blocks have no purpose left.

### What they still do, all of it unwanted

1. **They kill an explicit request.** `getSAMSitesByNatoName` returns *every* site of that type in
   the network, so a SA-10 marked as a watch — by the `ewr` spawn option or by hand in
   `mission-script.lua` — is silenced. Worse, the order of operations in `initializeIADS` means the
   enrolment loop sets the watch and the block right after it undoes it, so on these five types
   `ewr` has **never** worked, not even at first start-up.
2. **They send a stray `goDark()`.** `setActAsEW` calls `goDark()` outside its state-change test, so
   every group joining the network sends an extinction order to all SA-10, SA-6, SA-5, Patriot and
   Hawk in it. Bounded by `goDark`'s own guards and repaired on the next cycle, so minor — but it
   goes away with the blocks.
3. **They can break Flogas's point-defence mechanism.** `pointDefencesGoLive()` puts a point defence
   into `actAsEW(true)` so it watches while the site it protects is silenced by an anti-radiation
   missile. A point defence of one of the five types gets switched straight back off. Unlikely in
   practice, real all the same.

### What to remove

| Where | What |
|---|---|
| `veafSkynetIadsHelper.lua:1549-1560` | the block, its `if not batchMode and not forceEwr and not pointDefense` guard, and the "Specific configuration applied" trace |
| `veafSkynetIadsHelper.lua:1635-1642` | the twin block and its comment |
| `veafSkynetIadsHelper.lua:1370` | `batchMode` then only feeds one trace line. Keep both — the trace is useful when reading a log |
| `test/lua/test_veafSkynetIadsHelper.lua:116` | `natoMock` and `getSAMSitesByNatoName` in `_makeMockIads` exist only to absorb these calls |

### The risk, checked

A mission already using `ewr` on a SA-10, SA-6, SA-5, Patriot or Hawk would see that site **really
lit permanently** after the fix, where it is dark today — what its author asked for, but never seen,
so it would read as a regression.

**Swept on 2026-09-19**: none of the 84 repositories under `D:\dev\_VEAF` uses the option, outside
`node_modules` and `published` copies of veaf-tools itself. The only `ewr` occurrences are CTLD
vocabulary. Nothing to migrate.

### Definition of done

- Both blocks gone, the test mocks they required gone with them.
- A new test: mark a SA-10 as an EW watch, add another group to the network, assert the watch
  survives. It fails today.
- `poetry run test-lua` green, `CHANGELOG.md` updated.

## 02 — Document what a network SAM does and does not see

Status: ✅ done

### Problem

`doc/mission-maker/scripts/veafSkynetIadsHelper.md` explains what an IADS is for — sites stay dark
to survive, EWRs feed them contacts — and never states the consequence a mission maker actually
trips over:

> a site under network control has its radar switched off, so it cannot notice an aircraft above it;
> if no EWR sees the intruder, no SAM reacts, whatever the distance.

Nor does it say the corollary: destroying the EWRs makes the remaining sites *more* aggressive,
because they revert to the DCS AI. Both are surprising, both are correct, and both were reported as
bugs on 2026-09-17.

Two more things the page never says, both surfaced by that investigation:

- **"Covered" does not mean "informed".** Coverage is a flat 2D distance between the EWR's radar and
  the battery's, compared against the EWR's detection range — no horizon, no terrain, no altitude.
  It means the EWR is *near* the battery, never that it is feeding it. One 55G6 listed 18 batteries
  under its coverage in the reported log.
- **Joining the network depends on how the group arrived**: Mission Editor → yes; combat zone →
  yes, whatever `dynamic_spawn` says; VEAF spawn command → only if the command carries `skynet`;
  third-party script → only when `dynamic_spawn` is on. Two identical batteries behave in opposite
  ways depending on their origin.

The `ewr` spawn option — the one lever that gives a site permanent watch duty — is documented
nowhere on the mission-maker side.

### What to write

In `veafSkynetIadsHelper.md` and its `.en.md` twin, keeping anchors identical across languages:

1. The two conditions for a site to light up, and the fact that proximity alone is not one of them
   beyond the last-line-of-defense radius added on the Skynet side.
2. The last line of defense itself: a dark site keeps a short virtual detection radius of its own
   (10–15 km, drawn once per site), measured flat, and stays lit 45 s after the last pass. How to
   switch it off for a mission that wants a purist IADS, and the honest limit — a short-range piece
   can light up for an aircraft it cannot reach, because the radius ignores the firing envelope on
   purpose.
3. The EWR-loss inversion, stated as expected behaviour rather than left to be discovered.
4. What "covered" really means, so nobody reads the status page as "this battery is being watched".
5. The `ewr` spawn option: what a watch site is, what it costs (visible and targetable), and the
   advice to sacrifice a short-range battery rather than the system being protected.
6. A table of the four ways a group joins a network, per the list above.
7. The new `mission.yaml` keys, with their defaults, and the note that they are global to both
   coalitions while `dynamic_spawn` is per network.
8. How to diagnose: `debug_red: true`, then the three readings of the status page — EWR with no
   contacts, EWR with contacts but the site still `ACTIVE: false`, or site already `AUTONOMOUS`.

### Definition of done

- Both language files updated, both in the `nav`, anchors identical.
- `poetry run docs-check` green.

## 03 — Vendor Skynet 3.5.0

Status: ✅ done — vendored 2026-09-21; the in-game reading moved to `FEAT-SPOTTER-DEMO-MISSION`
ticket 05 (2026-10-04), 3.5.0 seen running in game 2026-10-03 (R1, R13)

### Take the release asset, do not rebuild

[**v3.5.0**](https://github.com/VEAF/Skynet-IADS/releases/tag/v3.5.0) attaches
`skynet-iads-compiled.lua` (164 772 bytes), built and verified against the DCS stub by
`.github/workflows/release.yml` from the tagged sources. Download that asset; there is no reason to
run the PowerShell build here any more, and doing so risks vendoring something the release does not
contain.

`vendored.yaml`'s `manual_steps` still says to recompile and to "re-apply the 'RP-VEAF' version
label". Both are obsolete — the label is gone and the version is plain `3.5.0`. Ticket 04 rewrites
that field; do not follow it as it stands.

### What this brings

The last line of defense and the coverage refresh — but **not only those**.

The artifact carried here identifies itself as `3.4.0RP-VEAF build 05.09.2026`, 4 362 lines against
the release's 5 087. Sixteen days and one whole lot separate them: `getCategory` centralised with its
nil protection (`29da7e6`), a SAM-goes-dark test suite (`f6d77e6`), SAM sites informed of inbound
weapons (`da60f1c`), the `syknet`→`skynet` typo sweep (`1cd651e`), and everything
`FEAT-LAST-LINE-OF-DEFENSE` added. Read the release notes before assuming it is inert — they are
552 lines and they open with a summary written for this repository.

### Three coverage fixes that change behaviour here, and are not in the settings table

These are in 3.5.0 and none of them is a new setting, so they are easy to miss when reading the
table below:

- **Declaring that a radar covers a battery used to switch that battery off.**
  `buildRadarAssociation()` ended in `resetAutonomousState()` → `goDark()`, and `goDark()`'s guards
  do not protect a site that has just gone live on designation and not yet locked on. Reached by
  every `addSAMSitesByPrefix()` / `addEarlyWarningRadarsByPrefix()` — which is exactly what
  `veafSkynetIadsHelper.lua` calls on respawn.
- **A bulk re-add left the elements it discarded wired into the coverage graph**, so a battery went
  on believing it was covered by a radar the IADS no longer polls, and stayed dark under nobody's
  watch. Same entry points.
- **A site torn down while evading a HARM stayed deaf for the rest of the mission**
  ([issue #3](https://github.com/VEAF/Skynet-IADS/issues/3)), including through
  `deactivate()`/`activate()`.

All three are improvements, but all three change what a VEAF mission does at respawn. Say so in the
PR rather than letting someone discover it in flight.

### Two more things the release changes, neither of them a setting

- **Setup warnings are shown on screen again.** Four messages — a group name absent from the
  mission, a unit name absent, an element of the wrong coalition, a group Skynet has no SAM data for
  — wrote one line to `dcs.log` and nothing else between November 2020 and 3.5.0. A mission that has
  quietly carried a typo will announce it on screen the first time it loads this build. **Check what
  the VEAF missions in `test/` produce before shipping**: if the helper generates any of these, every
  mission built by these tools starts printing a warning. The escape hatch is
  `getDebugSettings().warnings = false`, which keeps the log copy.
- **`SkynetIADS:addJammer()` is removed.** It raised *table expected, got nil* on every call, so
  nothing can have used it successfully — but grep the helper and the demo scripts anyway, because
  the failure mode changes from a DCS error to `attempt to call a nil value`.

MIST is also no longer needed by Skynet itself (no MIST call remains in the build). That is **not**
an invitation to drop MIST here: other VEAF scripts use it. Noted only so nobody re-adds it *for*
Skynet.

### New settings to surface

All of them in `mission.yaml` under `modules.SKYNET`, David's choice on 2026-09-19 — and therefore
`src/defaults/mission-folder/mission.yaml` in the same lot, per CLAUDE.md §9.7:

| Key | Default |
|---|---|
| last line of defense on/off | **on** — it changes existing missions, say so in the PR |
| radius bounds | 10–15 km, drawn once per site |
| persistence after the last pass | 45 s |
| coverage sweep interval | 10 s |

Global for both coalitions for now; per-network only if the need appears. Note in the doc that
`dynamic_spawn` is the one key that is already per network.

### The quality gate that matters here

**Execute the artifact against the DCS mocks, do not merely load it.** `assert(loadfile(f))` parses
the file and says nothing about a main chunk that raises at run time — that is exactly how CTLD rc8
passed the gate and killed every radio menu in the mission (#957). One raise takes down the whole
concatenated loading chunk.

Also re-run the mission build end to end and unzip the resulting `.miz` to read what actually
shipped, rather than trusting the yaml.

### It also unblocks the spotter network

[`FEAT-SPOTTER-NETWORK`](FEAT-SPOTTER-NETWORK.md) shipped on 2026-09-21 and is
**complete except for its in-game check**, which cannot run until this lands: its hand-over calls
`SkynetIADS:reportContact`, which exists in `VEAF/Skynet-IADS` and not in the artifact carried here.
Today a mission that switches the feature on gets one plain warning saying alerts travel and no site
is ever woken.

`test/veaf-tools/verify-mission-c` already runs with it on in `"radio"` mode, and its
[check 13](../../test/veaf-tools/verify-mission-c/README.md#check-13) says what to look for. **Run
it in the same DCS session as this ticket's own verification** — it is the only debt that lot has
left, and it is invisible from anywhere but here.

### Definition of done

- [x] The artifact is the `v3.5.0` release asset, and its banner reads
      `SKYNET VERSION: 3.5.0 | BUILD TIME: 21.09.2026 1038Z`. *(`1038Z`, not the `1011Z` written
      above: the release was rebuilt before publication. The asset is the one attached to the tag.)*
- [x] It loads **and runs** under Lua 5.1 with the DCS mocks —
      `test_community_scripts_load.lua::test_06_skynet_loads`, which executes the main chunk rather
      than parsing it.
- [x] `mission.yaml` and the shipped default carry the new keys, with the same names and defaults as
      the Skynet side. Spelled `last_line_of_defence` (British), matching the Skynet API
      (`setLastLineOfDefence`) and this page's documentation; the lot's own name uses the American
      spelling and the code follows the API it calls.
- [x] ~~**Check 13 of `verify-mission-c` run and its reading recorded**, which closes
      `FEAT-SPOTTER-NETWORK`.~~ Superseded 2026-10-04: the check cannot discriminate since the last
      line of defence is on (`FEAT-SPOTTER-DEMO-MISSION` ticket 04); the question is that lot's
      ticket 05.
- [x] `poetry run test-lua` (49 suites) and `poetry run pytest` green, `CHANGELOG.md` updated.

### The end-to-end build, read from the `.miz` rather than from the yaml

`verify-mission-c` rebuilt and unzipped on 2026-09-21:

- `l10n/DEFAULT/skynet-iads-compiled.lua` opens on
  `env.info("--- SKYNET VERSION: 3.5.0 | BUILD TIME: 21.09.2026 1038Z ---")`;
- it carries `SkynetIADS:reportContact`, `setLastLineOfDefence` and `setCoverageRefreshInterval`,
  and no longer carries `addJammer`;
- `veaf-config.lua` writes only the keys that mission declares, so the last-line-of-defence settings
  are absent from it and the Lua defaults stand — which is the documented behaviour, not an omission.

### On the setup warnings, stated as what it is

The four warnings are back on screen. Three of them the helper cannot plausibly produce: it adds SAM
sites and EWRs by names it just read off live DCS handles, and it already refuses a group whose
coalition does not match the network. The fourth — *"you have added an SAM site that Skynet IADS can
not handle"* — **is** plausible, because in `Lenient` mode a group qualifies on a single unit type
Skynet knows while Skynet's own group matching can still return `UNKNOWN`.

That cannot be measured without DCS, so it is **not** claimed either way here: it is written into
[check 13](../../test/veaf-tools/verify-mission-c/README.md#check-13) as something to read in the
same session. The escape hatch, if a VEAF mission turns out to produce them, is
`getDebugSettings().warnings = false`, which keeps the log copy.

## 04 — Repair the Skynet drift watch, which can no longer fire

Status: ✅ done

### The watch is pointed at a file that no longer exists

`vendored.yaml`'s first Skynet watch is:

```yaml
- { kind: github-file, repo: VEAF/Skynet-IADS, ref: master,
    file: demo-missions/skynet-iads-compiled.lua, pinned: "cde577d1ac79" }
```

`poetry run check-vendored` reports it `drifted`, at `112c5442bfef2…`. That looks like the watcher
working. It is not: **`112c544` is the commit that deleted the file.** Skynet stopped committing its
build artifact when its build was redone on the CTLD model — it is `.gitignore`d there now
(`.gitignore:12`) and rebuilt by CI — so the last commit touching that path is its removal, and it
will stay the last one forever.

Measured in the Skynet repository:

```
$ git log --diff-filter=D --oneline -1 origin/master -- demo-missions/skynet-iads-compiled.lua
112c544 ci: rebuild the build on the CTLD model, release on tag
```

So the current `drifted` reading is not "3.5.0 is out". It is "the file went away", and once ticket
03 moves the pin to `112c544` to silence it, **the watch becomes permanently green and permanently
blind**. Skynet 3.6.0 would ship without this repository hearing about it — which is precisely the
failure `vendored.yaml` exists to prevent, and precisely how the vendored copy ran a month behind
before.

### What to change

- **Replace the `github-file` watch with a `github-release` one** on `VEAF/Skynet-IADS`, pinned at
  the version ticket 03 vendors. Skynet publishes a GitHub release per tag now
  (`.github/workflows/release.yml`), carrying `skynet-iads-compiled.lua` as an asset — the same
  mechanism CTLD is watched through.
- **Exclude pre-releases.** A Skynet tag that is not a plain `vX.Y.Z` is published as a pre-release
  on purpose (a release candidate must never become what anyone vendors by default). Use the same
  `tag_pattern` mechanism ticket 02 of `CHORE-VENDORED-DRIFT-618` added for CTLD's floating `dev`
  tag, so a `v3.6.0-rc1` does not read as drift.
- **Rewrite `manual_steps`.** It currently reads:

  > *"Recompile skynet-iads-compiled.lua from the VEAF/Skynet-IADS sources
  > (build-tools/build-compiled-script.ps1), run stylua on it, and re-apply the 'RP-VEAF' version
  > label."*

  All three clauses are now wrong or unnecessary. There is nothing to recompile — the release ships
  the artifact. And there is no `RP-VEAF` label to re-apply: the Regroupement and VEAF maintain
  Skynet jointly as of 3.5.0, and the version is plain `3.5.0` precisely so that the number belongs
  to neither community alone.

- **Decide what `vendoring:` should say, and measure before deciding.** It is `compiled` today,
  which described recompiling here. Taking a published asset verbatim is what `verbatim` means, and
  a `verbatim` entry needs no `manual_steps` at all. The one thing that could argue for keeping a
  manual step is the `stylua` pass: the vendored copy has been formatted, the asset is not
  necessarily. **Measure it** — diff the release asset against the current vendored file after a
  `stylua` run and without one, and pick whichever keeps the *next* sync readable. Say which, and
  why, in the PR. Do not assume: a 4 000-line formatting diff is exactly what makes the following
  bump impossible to review, which is the reason the `stylua` clause was written in the first place.

- **Leave the two `upstream-ref` watches alone.** `regroupement-patrouille/Skynet-IADS` and
  `walder/Skynet-IADS` are historical archives; the note above the entry explains why they are still
  watched, and that reasoning is unchanged.

### Also update the note above the entry

The comment block says *"VEAF therefore forked the fork, and Flogas agreed on 2026-08-31 that
VEAF/Skynet-IADS becomes the main fork"*. That is still true and still the right history to keep.
Add one line: since 2026-09-21, VEAF and the Regroupement de Patrouilles (BFR, NAWACS) maintain the
project **jointly**, in that repository. It matters here because it is the reason the version label
lost its `RP` — someone reading only the old note would try to put it back.

### Acceptance

- [x] `check-vendored` reports the Skynet entry up to date against the release, not against a commit
      touching a deleted path.
- [x] A deliberate test: the pin was moved back to `v3.4.0` and the watcher reported `drifted`
      (`v3.4.0` → `v3.5.0`), then restored. A watch that cannot fail is worth nothing, and this
      ticket exists because one was found.
- [x] A pre-release tag does not read as drift.
- [x] `test_vendored_pins_match_the_files.py` green — and **extended**: the artifact's own banner is
      now read back and compared against `pinned:`, which the test file itself invited ("adding an
      artefact here is cheap and worth doing whenever an upstream starts declaring its version").
      That check needed one repair to be correct: `WATCH_TAG_CARRIES_THE_PIN` walked *every*
      `github-release` watch, so Skynet's walder `upstream-ref` at `3.3.0` would have failed against
      a pin of `3.5.0`. `upstream-ref` watches are now skipped — they answer a different question and
      carry the ancestor's numbering.
- [x] `manual_steps` describes what someone would actually do, and the `vendoring:` value matches it.

### What the measurements said, where they differ from this ticket

**The `stylua` pass stays, and it is not close.** Diffing the 3.5.0 release asset against the copy
carried here: **9 085** changed lines as published, **843** after running it through the repo's
`stylua` config. The asset is tab-indented, the repo config is two spaces. So `vendoring:` becomes
`adapted` rather than `verbatim`, and `manual_steps` keeps a second clause — download, then format.

**`tag_pattern` is the wrong mechanism, and setting it would have caused the defect it was meant to
avoid.** In `vendored_check.py` that field is only read when `prereleases: true`; without
`prereleases`, the watch asks `/releases/latest`, which skips pre-releases by design. Skynet's
release workflow marks any tag that is not a plain `vX.Y.Z` as a pre-release (measured in
`.github/workflows/release.yml`), so a plain `github-release` watch already ignores `v3.6.0-rc1`.
Turning `prereleases: true` on — with or without a pattern — would be the one way to make an rc read
as drift. The requirement this ticket stated is met; the remedy it named is not the one used.
