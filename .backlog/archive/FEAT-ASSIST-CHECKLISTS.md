# Lot FEAT-ASSIST-CHECKLISTS — guided checklists from YAML, cold start as first client

Status: ✅ done — **flown and validated by David on 2026-08-01**. Menu, on-screen checklist, ticking
steps and event texts all work. Four defects were found and fixed during the flight.

**Branch** → [#649](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/649) → `develop`
(the authoring follow-up is [#651](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/651), `FEAT-ASSIST-AUTHORING`)

⚠️ **Three items were still open when this was archived** — see *Still open* at the bottom. None is
blocking, and none is tracked anywhere else.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Primitives spike | ✅ |
| 02 | YAML format and emission | ✅ |
| 03 | Image generator | ✅ |
| 04 | Assist engine | ✅ |
| 05 | Menu and config | ✅ |
| 06 | F-16C checklist | ✅ (a pilot review still wanted) |
| 07 | Documentation | ✅ |
| 08 | Display mode | ✅ |
| 09 | Inline translations | ✅ |
| 10 | Switch position | ✅ |

## What it is

A **guided-checklist engine**. The mission shows a checklist, boxes the cockpit control the current
step needs, ticks the line as soon as that control reaches the right position — or as soon as the pilot
confirms it for a "check that…" step — and moves on. Reached from `Assistance` in the F10 menu. Cold
start is the **first client, not the feature**: the engine knows nothing about the F-16C.

An earlier draft emitted **two trigger rules per step**. David killed it: forty steps across several
aircraft would bury the mission maker's own triggers under hundreds of ours, in a panel already hard to
read. A runtime module driven by data emits **zero trigger rules** and is strictly better.

## Two design corrections, both mid-flight

**The primitives are not where the PRD said.** `a_cockpit_highlight` is *not* visible from the
environment VEAF scripts run in — the module refused to start because of it. Those functions live in the
**trigger** environment, reached with `net.dostring_in("mission", …)`, the same bridge
`TheUniversalMission` uses. Consequence worth remembering: **the module needs a de-sanitised
`MissionScripting.lua`**, since `net` is what a stock install strips.

**Validation by control position is impossible**, measured in game. The `argument:` field is now
*rejected by the format* with an error naming the alternatives, and `param:` reads a value the aircraft
**publishes** instead (`BASE_SENSOR_NOSE_GEAR_DOWN`, `BASE_SENSOR_IAS`, …). What genuinely cannot be
read in any environment: a spring-loaded switch (already back at neutral) and a button (no position).
Four of the six F-16C steps are pilot-confirmed for that reason, not for want of a mechanism.

## The four defects the flight exposed

- **The module never started** — the primitives-environment error above.
- **The picture came out unreadable.** `a_out_picture`'s `size` is a percentage **capped at 100** (ED's
  own default is 100), so 20 shrank it to a fifth — and since it can never enlarge, all legibility has
  to be rendered in. Fonts 26/20 → 42/32, canvas 436 → 720 px wide.
- **The first image showed raw i18n keys, later ones were fine.** The `.miz` was innocent: all seven
  embedded PNGs matched a fresh render byte-for-byte. **DCS caches embedded resources by name**, and
  state 0 was the only one already displayed with the earlier untranslated build. A full DCS restart
  cleared it.
- **Menu order put "skip" before "confirm"** — not this module's doing: `veafRadio` sorted commands
  alphabetically and in French *"passer"* sorts before *"valider"*. Commands now accept an optional
  `sortKey` the sort prefers, available to any module with an intended order.

Underneath those, one real bug: **the runtime catalogue was never found in a distribution.**
`published/` ships only the concatenated `veaf-scripts.lua`, never `veafI18n.lua`, so every checklist
picture built from a release would have shown raw keys. The reader accepts both now.

## The verdict this prototype existed to produce

**Does it work in game, for someone who did not write it?** Yes — David flew it and reported "ça
fonctionne bien" once the menu order and the cached image were sorted out.

**Was hand-writing the steps the bottleneck? No** — and this is the answer that matters for the
roadmap. Six steps took minutes once `Macro_sequencies.lua` was found. What cost time was everything
around them: choosing a coherent slice, noticing the JFS switch is spring-loaded, and above all
discovering that switch positions are unreadable. **A generator fed by `clickabledata.lua` +
`Macro_sequencies.lua` is therefore worth much less than the PRD assumed** — half of what it would
produce (argument windows) has nothing to bind to. That follow-up was deprioritised on this basis, and
`FEAT-ASSIST-AUTHORING` was later paused by David.

**Did the image display hold up?** Yes, after two corrections that were both about the API rather than
the design. The linear-progress compromise was never even noticed in flight.

**Multiplayer?** Still unknown.

**The door that stays open**: the *effect* of a control is readable even though the control is not.
`list_cockpit_params` publishes altitude, speed, heading, gear, canopy, flaps and fuel, live. A bomb run
— the PRD's own second client — is fully automatic on that basis. An engine start is not: it is a
*guided and confirmed* checklist.

## Still open — nothing tracks these now

1. **Two pilots at once**, and whether a highlight leaks into another cockpit. The per-session highlight
   id exists for this; it has never been exercised.
2. **A pilot review of the F-16C slice** (ticket 06).
3. **Resource names should probably carry a content hash.** The stale-picture trap above cost an evening
   and would hit any mission maker iterating on a checklist, with a symptom — "the text is wrong but
   only on the first image" — that points nowhere near the cause. Cheap to prevent.

**Unverified optimisation**: `c_cockpit_param_in_range` exists in the mission environment and would let
the engine ask a question instead of parsing a ~19 KB dump once per tick. Its signature was never
probed — DCS had been closed by then.
