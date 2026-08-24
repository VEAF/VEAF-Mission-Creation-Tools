# FEAT-CTLD-SLINGLOAD-TOGGLE — no way to turn CTLD sling loading on or off in flight

Status: ⬜ ready

Origin: [#60](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/60), 2021.

## The gap

The ask is a command to enable or disable CTLD sling loading. Grepped: no `sling` toggle anywhere in
the radio layer.

The reason it matters is practical rather than technical — sling loading changes how a helicopter crew
plays a mission, and a game master pacing a training wants to switch it without editing a file and
rebuilding.

## Scope

A radio entry under the CTLD menu, toggling CTLD's own sling-load flag at runtime.

Cheaper than it was in 2021, and for a reason worth knowing: CTLD 2 is configured by the mission's
`ctld-config.yaml` (ADR 0016) and is now genuinely initialised
(`FIX-CTLD-NEVER-INITIALIZED`), so there is a live, configured CTLD to talk to. Two things to settle
by reading CTLD 2 rather than CTLD 1:

- **Which flag.** CTLD 1's name for it may not have survived the migration — the stale-comment trap
  that made #72's first verdict wrong.
- **Whether flipping it mid-mission is honoured** or only read at startup. If it is startup-only, the
  answer is a `ctld-config.yaml` key plus a clear message, not a radio toggle that lies.

## The open questions, settled — 2026-08-24

Read out of the vendored CTLD 2 (`2.0.0-rc7`) rather than remembered from CTLD 1.

**The flag is `enableHoverSlingload`** (`src/scripts/community/CTLD.lua:3062`, boolean, default `true`).
It is the gate of CTLD 2's "Virtual Slingload" feature — hover pickup, `hoverTime` countdown, crate lost
on overspeed — which is what a helicopter crew experiences as CTLD sling loading.

**`slingLoad` (`CTLD.lua:3188`) is a false friend.** The CTLD 1 name survived; its meaning did not. In
CTLD 2 it only chooses which `spawnableCratesModels` entry a crate uses when it appears, and all three
models declare `canCargo: true` — so `slingLoad: false` changes a crate's 3D model and nothing else.
Wiring the toggle to it would ship a radio command that reskins crates and does nothing a crew notices.
That is the trap this PRD feared, inverted: the name survived, the semantics did not.

**Verdict: runtime-toggleable, reversibly, with no menu rebuild.** `enableHoverSlingload` is read in
exactly one place, `CTLD.lua:13280`, inside `CTLDCrateManager:checkHoverStatus()` — a one-second timer
loop that **reschedules itself unconditionally before testing the flag** (`CTLD.lua:13256-13259`, the
upstream comment says so: *"Reschedule unconditionally"*). So flipping it off stops pickups at the next
tick and flipping it back on resumes them. The loop's start (`CTLD.lua:12451`) is not conditioned on the
flag either. And CTLD's own "Release / Cut Slingload" entries are gated on the per-type
`caps.canSlingload`, never on this flag, so the F10 menu cannot fall out of step.

The read path is live end to end: `ctld.gs(key)` → `CTLDConfig.get():getSetting(key)` → `self.settings`,
and `CTLDConfig:setSetting(key, value)` writes into that same table, which `getSetting` consults **before**
falling back to the embedded catalogue. A `setSetting` therefore always wins.

### What that changes about the plan

- **There is no VEAF radio menu for CTLD** to add an entry "under": zero `CTLD` references in
  `veafRadio.lua`, and CTLD builds its own F10 menu inside the vendored script. So the lot creates a
  VEAF submenu, on the `veafAssets` pattern, with the enable/disable pair built the way
  `veafCombatZone.lua:1812-1831` does it — only one of the two commands present at a time, then
  `veafRadio.refreshRadioMenu()`. A **secured** command with `USAGE_ForAll` fits a game-master lever.
- **No vendored file needs touching.** `CTLDConfig` and `ctld.gs` are globals, and VEAF already calls
  CTLD 2 singletons directly behind `veaf.isCtldReady()` — `CTLDJTACManager`, `CTLDZoneManager`,
  `CTLDBeaconManager`. The `verbatim` vendoring is preserved.
- **The `ctld-config.yaml` fallback was moot, and would have been free.** There is no schema to extend:
  `veaf_libs/ctld_config.py` extracts the whole catalogue out of the vendored `CTLD.lua`, so both keys are
  already present in every generated `ctld-config.yaml`.
- **A trap the message must name.** `_checkNativeDCSCargo()` runs at `CTLD.lua:13278`, *before* the flag
  test, with the upstream comment *"always, independent of slingload config"* — and all three crate models
  are `canCargo: true`. So neither flag stops a pilot physically winching a CTLD crate with DCS's own
  sling. Turning the toggle off disables CTLD's **virtual** sling loading, not the game's. If the on-screen
  message does not say so, the toggle will be reported as broken by the first crew that hooks a crate.

### Decided — 2026-08-24

**The toggle is global**, not per-coalition (David). So one pair of commands, one setting, and no
coalition argument to thread through — `CTLDConfig.get():setSetting("enableHoverSlingload", …)` is
already global, which is what makes this the cheap shape.

### Still to decide before implementing

- the wording that distinguishes CTLD's virtual sling loading from DCS's own winch. Nothing else: the
  global-versus-per-coalition question is answered above.

## Definition of done

- [ ] Sling loading can be switched from the radio menu, or — if the runtime only reads it at startup —
      a config key ships instead, and the toggle is **not** faked
- [ ] Which of those two it is, recorded here with the CTLD 2 evidence
- [ ] The menu label localised (`FIX-RADIO-MENU-I18N` made that the rule)
- [ ] Documented, both languages
