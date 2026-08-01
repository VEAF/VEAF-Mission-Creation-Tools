# FEAT-ASSIST-CHECKLISTS — guided checklists from YAML, cold start as first client

**Status:** ⬜ ready — ticket 01 done (the cockpit primitives are proven in game). Prototype delivers the
engine plus one checklist: F-16C cold start.

Opened 2026-08-01, design settled with David the same evening. Every decision below was taken with him
and is not open for re-litigation by the implementer.

## What this is

A **guided-checklist engine**. The mission shows a checklist, boxes the cockpit control the current step
needs, ticks the line as soon as that control reaches the right position — or as soon as the pilot
confirms it for a "check that…" step — and moves on. Reached from the F10 radio menu under
`Assistance`, one entry per applicable checklist (`Assistance / Cold start`, later
`Assistance / Bomb run`).

Cold start is the **first client**, not the feature. The engine knows nothing about the F-16C.

## Why it can be built

The cockpit machinery ED uses for its own training missions is not restricted to trigger actions: those
are **native functions reachable from the mission scripting environment**, verified in game
([ticket 01](tickets/01-primitives-spike.md)):

```
highlight=function  remove=function  perform=function
a_cockpit_highlight(100, 'PTR-ELEC-TMB-MPWR-510')  →  ok=true, box visible in the cockpit
```

An earlier draft of this lot emitted **two trigger rules per step**. David killed it: forty steps across
several aircraft would bury the mission maker's own triggers under hundreds of ours, in a panel that is
already hard to read. A runtime module driven by data emits **zero trigger rules** and is strictly
better.

## The YAML

Design-time only — DCS has no YAML reader, so the build converts each checklist into a Lua table
embedded in the `.miz`, like the rest of the VMCT chain.

```yaml
# checklists/f16c-cold-start.yaml
id: f16c-cold-start
title: assist.f16c.coldstart.title
aircraft: [F-16C_50]
menu: cold-start                     # → Assistance / Cold start

steps:
  - label: assist.f16c.main_pwr      # "MAIN PWR → MAIN PWR"
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510
    equals: 1.0
    tolerance: 0.05

  - label: assist.f16c.check_hyd     # "check the hydraulic circuits"
    element: PTR-HYDCP-IND-3018      # boxed anyway: shows where to look
    confirm: true                    # ticked by the pilot from the radio menu

  - label: assist.f16c.jfs_start2
    element: PTR-ENGSTART-TMB-JETFUEL-447
    argument: 447
    equals: -1.0
    tolerance: 0.05
```

Two rules: **an `argument` means automatic validation**, no argument means the pilot confirms. `element`
is optional *independently* of the mode — hence step 2, where the gauge is boxed to show where to look
while the pilot is the one who says it is good.

`equals` + `tolerance` covers the common case; `range: [min, max]` stays available for wide windows.

## Extensibility, for the bomb run

One door, rather than inventing a condition language now: a **named** check with parameters.

```yaml
  - label: assist.bombrun.altitude
    check: {type: altitude_above, value: 15000, unit: feet}
```

The engine holds a registry — `veafAssist.registerCheck("altitude_above", fn)` — and `argument` /
`confirm` are simply the two checks registered by default. A bomb-run lot adds checks (altitude, speed,
heading, distance to a point, selected weapon) without touching the engine or the format.

## The display: an image, plus short texts

The checklist is shown as a **generated image**, persistent on screen. `a_out_picture_*` resolves an
embedded resource through `getValueResourceByKey`, and per `me_trigrules.lua` a **duration of 0 keeps
the picture up until `a_out_picture_stop`** (ED's own comment, DCSCORE-2754). A working call already
exists in our tree, in [TheUniversalMission.lua:794](../../src/scripts/community/TheUniversalMission.lua).

Since the resource must be embedded, images are **pre-generated at build time, one per progress state** —
twelve steps, thirteen images. Pillow is already a dependency and
[presets_manager.py](../../src/python/veaf-tools/presets_injector/presets_manager.py) already draws
kneeboard images with fonts, so this reuses an existing pattern.

Two consequences, both accepted by David:

- **Only activated checklists are converted.** The build knows which ones the mission enables; the
  catalogue is never rendered wholesale. Indexed PNG of flat text runs 10-20 KB, so a forty-step
  checklist costs around 500 KB and a mission that activates nothing costs nothing.
- **Progress is linear.** With one image per step, the "step 5" image shows the first four ticked — so a
  step the pilot *skipped* looks ticked like any other. Representing "skipped" faithfully would need one
  image per combination, which explodes. The exception is carried by text instead: a short message when
  a step is skipped.

So the two channels have distinct roles: **the image is the dashboard** (persistent checklist), **short
texts carry events** (step validated, step skipped, checklist complete). No image is rebuilt for a
message, and the pilot still gets feedback when the image is hidden.

## Decisions taken

- **Runtime module, zero trigger.** Above.
- **Labels are i18n catalog keys**, and a literal string is tolerated: `veaf.t()` returns an unknown key
  unchanged, so a mission maker can write plain text in their own checklist without touching a catalog.
  No inline `{fr:…, en:…}` in the YAML. Per [ADR 0006](../../docs/adr/0006-lua-runtime-i18n.md).
- **A pilot can skip the current step.** A mis-measured argument window would otherwise strand the whole
  checklist with no recourse.
- **Already-satisfied steps are ticked on start.** Free, since checks read real state, and it makes the
  assistance usable by someone who started half-way.
- **Checklists live in sidecar files, not in `mission.yaml`.** Same profile as the CTLD 2 configuration —
  long, generic, unrelated to a mission's identity — and the same call as
  [ADR 0016](../../docs/adr/0016-ctld2-sidecar-configuration.md). A VMCT-shipped catalogue, plus a
  `checklists/` folder in the mission folder whose ids override it. `mission.yaml` carries only
  `modules: assist:`.
- **No live Mission Editor involved.** [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md)
  rejected that bridge; this lot never needed it.

## Out of scope

- Bomb run, and any checklist other than F-16C cold start. The check registry exists so that lot is
  additive; designing for it now would mean designing for an imaginary second client.
- Demonstration mode (`a_cockpit_perform_clickable_action`) and seat locking. The step data carries
  device/command so it stays possible.
- Generating step data from `clickabledata.lua` / `Macro_sequencies.lua` — a follow-up lot. It looks more
  promising than "extract the element inventory": `Macro_sequencies.lua` holds **ED's own autostart
  sequence, 106 labelled steps for the F-16C**, each with label, device, command and target value, plus
  named verification conditions. So the follow-up is a *cross* of the two files (elements from one,
  ordering and wording from the other), for the five modules that ship one. Still a separate lot — but
  ticket 06 already draws its order and labels from that source rather than inventing them.
- Multiplayer beyond ticket 01's open question: whether a highlight is visible to a second player.
- Chuck's Guides as a shipped artifact. The start-up *sequence* is a technical fact from the aircraft
  manual and using it is fine; copying his text or screenshots is not, and the PDF does not enter the
  repo. If we ever want to credit him as a source, we ask him first.

## Tickets

| # | Ticket | Depends on |
|---|---|---|
| 01 | [Prove the cockpit primitives from the mission environment](tickets/01-primitives-spike.md) | — (**✅ done**) |
| 02 | [Checklist YAML: schema, loader, Lua emission](tickets/02-yaml-format-and-emission.md) | 01 |
| 03 | [Checklist image generator](tickets/03-image-generator.md) | 02 |
| 04 | [`veafAssist.lua` — the engine](tickets/04-assist-engine.md) | 02 |
| 05 | [Radio menu, i18n and `mission.yaml` wiring](tickets/05-menu-and-config.md) | 03, 04 |
| 06 | [F-16C cold-start checklist, six steps](tickets/06-f16c-checklist.md) | 02 |
| 07 | [Document the prototype and its verdict](tickets/07-documentation.md) | 05, 06 |
