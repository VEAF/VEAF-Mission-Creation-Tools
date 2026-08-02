# FEAT-ASSIST-CHECKLISTS — guided checklists from YAML, cold start as first client

**Status:** ✅ done — **flown and validated by David on 2026-08-01**. Menu, on-screen checklist,
ticking steps and event texts all work. Four defects were found and fixed during the flight; the
verdict the prototype existed to produce is written below. What remains is not blocking: multiplayer
is untested, and the F-16C slice still wants a pilot's review.

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

The cockpit machinery ED uses for its own training missions is not restricted to trigger actions: it is
callable from a script, verified in game ([ticket 01](tickets/01-primitives-spike.md)):

```
a_cockpit_highlight(100, 'PTR-ELEC-TMB-MPWR-510')  →  ok=true, box visible in the cockpit
```

> **Corrected 2026-08-01, after the first flight.** Those functions are *not* in the environment VEAF
> scripts run in — this paragraph originally said they were, and the module refused to start because
> of it. They live in the **trigger** environment, reached with `net.dostring_in("mission", …)`, the
> same bridge `TheUniversalMission` uses. Consequence: the module needs a de-sanitised
> `MissionScripting.lua`, since `net` is what a stock install strips.

An earlier draft of this lot emitted **two trigger rules per step**. David killed it: forty steps across
several aircraft would bury the mission maker's own triggers under hundreds of ours, in a panel that is
already hard to read. A runtime module driven by data emits **zero trigger rules** and is strictly
better.

## The YAML

Design-time only — DCS has no YAML reader, so the build converts each checklist into a Lua table
embedded in the `.miz`, like the rest of the VMCT chain.

> **Corrected 2026-08-01.** The original design validated a step on an animation `argument`, i.e. on
> the **position of a control**. That cannot be read from a mission — measured in game, see *Probed in
> game* below — so the field is now rejected and `param` reads a value the aircraft *publishes*
> instead. The shape of the format is otherwise unchanged.

```yaml
# checklists/f16c-cold-start.yaml
id: f16c-cold-start
title: assist.f16c.coldstart.title
aircraft: [F-16C_50]
menu: cold-start                     # → Assistance / Cold start

steps:
  - label: assist.f16c.main_pwr      # "MAIN PWR → MAIN PWR"
    element: PTR-ELEC-TMB-MPWR-510   # boxed: shows where to look
    confirm: true                    # ticked by the pilot from the radio menu

  - label: assist.gear_down
    param: BASE_SENSOR_NOSE_GEAR_DOWN
    equals: 1.0
    tolerance: 0.05
```

Two rules: **a `param` means automatic validation**, no param means the pilot confirms. `element` is
optional *independently* of the mode — a gauge can be boxed to show where to look while the pilot is
the one who says it is good.

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
| 02 | [Checklist YAML: schema, loader, Lua emission](tickets/02-yaml-format-and-emission.md) | 01 (**✅ done**) |
| 03 | [Checklist image generator](tickets/03-image-generator.md) | 02 (**✅ done**) |
| 04 | [`veafAssist.lua` — the engine](tickets/04-assist-engine.md) | 02 (**✅ done**) |
| 05 | [Radio menu, i18n and `mission.yaml` wiring](tickets/05-menu-and-config.md) | 03, 04 (**✅ done**) |
| 06 | [F-16C cold-start checklist, six steps](tickets/06-f16c-checklist.md) | 02 (**🧑 slice to review by a pilot**) |
| 07 | [Document the prototype and its verdict](tickets/07-documentation.md) | 05, 06 (**✅ done**) |

## Probed in game — 2026-08-01

| # | Question | Answer |
|---|---|---|
| 1 | Does `Unit:getDrawArgumentValue` report a **cockpit switch** position? | ❌ **No.** MAIN PWR moved OFF → BATT → MAIN PWR, argument 510 stayed `0`. `c_player_unit_argument_in_range`, the documented fallback, is equally blind. `list_cockpit_params()` (562 entries, 78 live) exposes **no control position at all**. Details in [the exploration note](../../docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md), section 3 |
| 2 | Is `a_out_picture_u` reachable? | ✅ Yes, with the whole `a_*` family (114 functions), and ED's source settles `seconds = 0` |
| 3 | Argument windows for 510 / 757 | ⛔ Moot — there is nothing to measure |
| 4 | Picture legible over a cockpit, alignment, size | ⬜ Not yet |
| 5 | F10 menu behaviour | ⬜ Not yet |
| 6 | Two pilots assisted at once | ⬜ Not yet |
| 7 | Highlight visible to a second player | ⬜ Not yet |

**What survives:** the boxing (`a_cockpit_highlight`, proven in game at ticket 01), the picture, the
`confirm` mode, the YAML format, the engine, the menu, the image generation. The check registry too —
it is the extension point this now has to be used through.

**What falls:** validation by control position. Three of the six F-16C steps can never self-tick.

**The door that stays open:** the *effect* of a control is readable even though the control is not.
`list_cockpit_params` publishes altitude, speed, heading, gear, canopy, flaps and fuel, live. A bomb
run — the PRD's own second client — is well served by that. An engine start is not.

## First flight — 2026-08-01 evening

David flew it. **It works**: the menu appears, the checklist shows on screen, the steps tick, the
event texts land. Two defects were fixed on the spot, two remain for tomorrow.

Fixed during the session:

- **The module never started.** `a_cockpit_highlight` is not visible from where VEAF scripts run —
  the primitives live in the *trigger* environment and the only bridge is
  `net.dostring_in("mission", …)`, exactly what `TheUniversalMission` uses for its own picture
  output. The engine goes through that bridge now. Consequence worth keeping in mind: **the module
  needs a de-sanitised `MissionScripting.lua`**, since `net` is one of the things a stock install
  strips.
- **The picture came out unreadable.** `a_out_picture`'s `size` is a percentage **capped at 100**
  (ED's own default is 100), so 20 shrank it to a fifth — and since it can never enlarge, all the
  legibility has to be rendered in. Fonts 26/20 → 42/32, canvas 436 → 720 px wide.

Two more defects were reported and fixed the same evening:

- **The first image showed raw i18n keys, later ones were fine.** The `.miz` was innocent — all seven
  embedded PNGs matched a fresh render byte-for-byte. **DCS caches embedded resources by name**, and
  state 0 was the only one already displayed with the earlier, untranslated build. A full DCS restart
  cleared it. See *Still open* below: the file names should probably carry a content hash.
- **Menu order put "skip" before "confirm".** Not this module's doing: `veafRadio` sorted commands
  alphabetically, and in French *"passer"* sorts before *"valider"*. Commands now accept an optional
  `sortKey` the sort prefers — same shape as the `groupFilter` addition, and available to any module
  with an intended order.

Underneath those, one real bug the flight exposed: **the runtime catalogue was never found in a
distribution.** `published/` ships only the concatenated `veaf-scripts.lua`, never `veafI18n.lua`, so
every checklist picture built from a release would have shown raw keys. The reader accepts both now.

## Verdict — the four questions this prototype existed to answer

**Does it work in game, for someone who did not write it?** Yes. David flew it and reported "ça
fonctionne bien" once the menu order and the cached image were sorted out.

**Was hand-writing the steps the bottleneck?** **No** — and this is the answer that matters for the
roadmap. Six steps took minutes once `Macro_sequencies.lua` was found. What actually cost time was
everything around them: choosing a coherent slice, noticing the JFS switch is spring-loaded, and
above all discovering that switch positions are unreadable. A generator fed by `clickabledata.lua` +
`Macro_sequencies.lua` would therefore be worth **much less** than the PRD assumed — half of what it
would produce (argument windows) has nothing to bind to. Deprioritise that follow-up lot.

**Did the image display hold up?** Yes, after two corrections that were both about the API rather
than the design: `size` is capped at 100 so nothing can be enlarged at display time, and the
resource cache serves stale bitmaps across rebuilds. The linear-progress compromise was never even
noticed in flight — it is fine.

**Multiplayer?** Still unknown. Nobody has had two pilots assisted at once, and whether a highlight
leaks into another cockpit is still the open question from ticket 01.

## Still open

- **Two pilots at once**, and highlight visibility for a second player. The per-session highlight id
  exists for this; it has never been exercised.
- **A pilot review of the F-16C slice** (ticket 06).
- **Resource names should probably carry a content hash.** The stale-picture trap cost an evening
  here and would hit any mission maker iterating on a checklist, with a symptom — "the text is wrong
  but only on the first image" — that points nowhere near the cause. Cheap to prevent.

## The design call — settled 2026-08-01

David chose **confirm-first plus a `cockpit_param` check**, and both are implemented:

- The F-16C checklist is **pilot-confirmed throughout**; its three automatic steps are gone.
- The `argument:` field is **rejected by the format** with an error naming the alternatives, and the
  engine registers no `argument` check — so a hand-written checklist cannot resurrect it silently.
- A step's **`param:`** reads a live cockpit parameter (`BASE_SENSOR_NOSE_GEAR_DOWN`,
  `BASE_SENSOR_IAS`, …) and ticks when it enters the window. `equals` / `tolerance` / `range` are
  unchanged; only what they apply to moved from a control to a published value. The engine parses
  `list_cockpit_params()` **once per tick**, shared by every session and step, because the dump is
  ~19 KB of text.

The upshot for the roadmap: an engine-start checklist is a *guided and confirmed* one, while the bomb
run the PRD names as the second client — altitude, speed, heading, distance — is fully automatic. The
value of a step-data generator (the follow-up lot) drops accordingly: writing steps was never the
bottleneck, and half of what it would have generated is unusable.

**Unverified optimisation:** `c_cockpit_param_in_range` exists in the mission environment and would
let the engine ask a question instead of parsing a dump. Its signature was not probed — DCS had been
closed by then.
