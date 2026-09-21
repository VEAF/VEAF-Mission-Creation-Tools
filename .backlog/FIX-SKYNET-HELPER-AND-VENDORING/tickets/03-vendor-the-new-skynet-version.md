# 03 — Vendor Skynet 3.5.0

Status: 🧑 waiting-human — vendored 2026-09-21; only the in-game reading is owed

## Take the release asset, do not rebuild

[**v3.5.0**](https://github.com/VEAF/Skynet-IADS/releases/tag/v3.5.0) attaches
`skynet-iads-compiled.lua` (164 772 bytes), built and verified against the DCS stub by
`.github/workflows/release.yml` from the tagged sources. Download that asset; there is no reason to
run the PowerShell build here any more, and doing so risks vendoring something the release does not
contain.

`vendored.yaml`'s `manual_steps` still says to recompile and to "re-apply the 'RP-VEAF' version
label". Both are obsolete — the label is gone and the version is plain `3.5.0`. Ticket 04 rewrites
that field; do not follow it as it stands.

## What this brings

The last line of defense and the coverage refresh — but **not only those**.

The artifact carried here identifies itself as `3.4.0RP-VEAF build 05.09.2026`, 4 362 lines against
the release's 5 087. Sixteen days and one whole lot separate them: `getCategory` centralised with its
nil protection (`29da7e6`), a SAM-goes-dark test suite (`f6d77e6`), SAM sites informed of inbound
weapons (`da60f1c`), the `syknet`→`skynet` typo sweep (`1cd651e`), and everything
`FEAT-LAST-LINE-OF-DEFENSE` added. Read the release notes before assuming it is inert — they are
552 lines and they open with a summary written for this repository.

## Three coverage fixes that change behaviour here, and are not in the settings table

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

## Two more things the release changes, neither of them a setting

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

## New settings to surface

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

## The quality gate that matters here

**Execute the artifact against the DCS mocks, do not merely load it.** `assert(loadfile(f))` parses
the file and says nothing about a main chunk that raises at run time — that is exactly how CTLD rc8
passed the gate and killed every radio menu in the mission (#957). One raise takes down the whole
concatenated loading chunk.

Also re-run the mission build end to end and unzip the resulting `.miz` to read what actually
shipped, rather than trusting the yaml.

## It also unblocks the spotter network

[`FEAT-SPOTTER-NETWORK`](../../archive/FEAT-SPOTTER-NETWORK.md) shipped on 2026-09-21 and is
**complete except for its in-game check**, which cannot run until this lands: its hand-over calls
`SkynetIADS:reportContact`, which exists in `VEAF/Skynet-IADS` and not in the artifact carried here.
Today a mission that switches the feature on gets one plain warning saying alerts travel and no site
is ever woken.

`test/veaf-tools/verify-mission-c` already runs with it on in `"radio"` mode, and its
[check 13](../../../test/veaf-tools/verify-mission-c/README.md#check-13) says what to look for. **Run
it in the same DCS session as this ticket's own verification** — it is the only debt that lot has
left, and it is invisible from anywhere but here.

## Definition of done

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
- [ ] **Check 13 of `verify-mission-c` run and its reading recorded**, which closes
      `FEAT-SPOTTER-NETWORK`. ⏸ **needs DCS** — the only item left in this lot.
- [x] `poetry run test-lua` (49 suites) and `poetry run pytest` green, `CHANGELOG.md` updated.

## The end-to-end build, read from the `.miz` rather than from the yaml

`verify-mission-c` rebuilt and unzipped on 2026-09-21:

- `l10n/DEFAULT/skynet-iads-compiled.lua` opens on
  `env.info("--- SKYNET VERSION: 3.5.0 | BUILD TIME: 21.09.2026 1038Z ---")`;
- it carries `SkynetIADS:reportContact`, `setLastLineOfDefence` and `setCoverageRefreshInterval`,
  and no longer carries `addJammer`;
- `veaf-config.lua` writes only the keys that mission declares, so the last-line-of-defence settings
  are absent from it and the Lua defaults stand — which is the documented behaviour, not an omission.

## On the setup warnings, stated as what it is

The four warnings are back on screen. Three of them the helper cannot plausibly produce: it adds SAM
sites and EWRs by names it just read off live DCS handles, and it already refuses a group whose
coalition does not match the network. The fourth — *"you have added an SAM site that Skynet IADS can
not handle"* — **is** plausible, because in `Lenient` mode a group qualifies on a single unit type
Skynet knows while Skynet's own group matching can still return `UNKNOWN`.

That cannot be measured without DCS, so it is **not** claimed either way here: it is written into
[check 13](../../../test/veaf-tools/verify-mission-c/README.md#check-13) as something to read in the
same session. The escape hatch, if a VEAF mission turns out to produce them, is
`getDebugSettings().warnings = false`, which keeps the log copy.
