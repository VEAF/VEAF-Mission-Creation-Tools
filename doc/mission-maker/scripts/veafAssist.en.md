# veafAssist — Guided checklists

**Module ID:** `ASSIST` | **File:** `veafAssist.lua`

---

## Purpose

Walks a pilot through a procedure, step by step. At each step the module **boxes the cockpit
control** to operate, **ticks the line** as soon as that control reaches the right position — or as
soon as the pilot confirms it themselves — and moves on. The whole checklist stays on screen as a
picture.

The module knows nothing about any aircraft: checklists are **data**, written in YAML and converted
when the mission is built.

One aircraft ships with a checklist: the **F-16C** (engine start).

---

## For pilots {#for-pilots}

F10 radio menu → `Assistance`. One entry per checklist that applies to your aircraft; if yours has
none, no entry appears.

Once a checklist is running, the menu offers:

| Entry | Effect |
|---|---|
| Confirm this step | Ticks the current step — **only** for steps that wait on your confirmation |
| Skip this step | Ticks the step without doing it, and moves on |
| Hide / show the checklist | Hides or brings back the picture |
| Stop the assistance | Ends the session, clears the box and the picture |

Two behaviours worth knowing in advance:

- **Steps already done are ticked on start.** You can call for assistance half-way through a
  procedure: what you have already set is not asked for again.
- **A step can be skipped.** If a step refuses to validate — a mis-measured tolerance window, say —
  `Skip this step` keeps you from being stranded.

A **skipped** step shows as ticked like any other on the picture; the text message is what tells you
at the time. The picture is the dashboard, the texts carry the events.

---

## For mission makers {#for-mission-makers}

### Enable the module {#enable}

```yaml
modules:
  ASSIST:
    enabled: true
    display: picture                # `picture` (default) or `text`
    checklists: [f16c-cold-start]   # the checklists this mission activates
```

- **With a `checklists:` list**: exactly those. An unknown `id` fails the build, rather than leaving
  a menu entry silently missing.
- **With no list**: the checklists you dropped in your mission's `checklists/` folder are activated.
  **Never the whole shipped catalogue** — every activated checklist embeds one picture per step in
  the `.miz`.
- **Module absent or `enabled: false`**: nothing is loaded, nothing is generated, no image in the
  `.miz`.

### Picture or text {#display-mode}

`display` chooses how the checklist is shown, and it is a **build-time** choice:

| Mode | What the pilot sees | What it costs |
|---|---|---|
| `picture` (default) | the whole checklist on screen, lines ticking as you go | one image per step embedded in the `.miz`, around 10 KB each |
| `text` | a message giving the current instruction and the progress (`Step 3/6: …`) | **nothing**: no image is rendered or embedded |

The cockpit control is boxed either way: text mode drops the picture, not the assistance. An
unrecognised value fails the build — a typo must not quietly fall back to the expensive mode.

Concretely, the shipped F-16C checklist weighs 68 KB as `picture` and 0 as `text`. At forty steps the
difference passes half a megabyte.

### Without knowing the technical names {#instructor-path}

A step needs the cockpit element, the animation argument and the value that means "in position".
All three are buried in the Lua files of a DCS install — nobody should have to go and find them.

Describe the control **in your own words** instead, beside the label:

```yaml
steps:
  - label: Battery
    control: MAIN PWR sur BATT      # the control, then the position you want

  - label: Throttle
    control: throttle sur IDLE
```

Then run:

```bash
veaf-tools cockpit resolve-checklist checklists/my-checklist.yaml
```

It fills in the technical fields **in your own file**, under each `control`, and adds a
`resolved_from` recording the text they came from:

```yaml
  - label: Battery
    control: MAIN PWR sur BATT
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510
    equals: 0.0
    resolved_from: MAIN PWR sur BATT
```

Your comments, your indentation and your blank lines survive: it is your file.

**One file to maintain.** Edit a `control`, run the command again: only the steps whose text changed
are touched — that is what `resolved_from` is for. A step whose `control` no longer matches its
`resolved_from` **fails the mission build**, rather than shipping a step that would check the old
control with nobody the wiser.

`--dry-run` shows what would be written without touching the file.

#### Writing a good `control` {#good-control}

Name the control **as the cockpit names it**, then the position: `throttle sur idle`, not "throttle
up". Filler words (`sur`, `the`, `button`, `switch`, `position`…) are ignored, in English and in
French alike, and accents and case do not matter.

#### A refusal is not a failure {#refusals}

The tool **refuses rather than guesses**, because a wrong resolution produces a checklist that looks
finished and never validates — and you only find out sitting in the cockpit. It refuses, saying what
it found, when:

- no control matches;
- several match equally well (`MAIN PWR` and `MAIN PWR Test`): only you know which;
- the position named does not exist on that control — it then lists the ones that do;
- that control's position values are unknown. Most of the AH-64D's controls are like this: write
  `argument` and `equals` by hand, or measure the position in game.

If a single step is refused, **nothing is written**: a half-resolved file is worse than an unresolved
one.

Finally, a control with **no readable position** — a button, or a spring-loaded switch like the
F-16C's JFS — resolves to a pilot-confirmed step, and the tool tells you so. That is not a
shortcoming: those controls are back at rest before anything can read them, by any means.

#### Exploring a cockpit {#explore}

Writing a checklist means knowing three things about a control: its element, its animation argument,
and the value of the position you want. This command gives you all three **by handling the
cockpit**, with nothing to read:

```bash
veaf-tools cockpit explore-cockpit F-14BU
```

Move a switch: the tool names it, and prints the step ready to paste into your file. The value is
**measured**, not inferred. Ctrl-C to stop.

This is what unblocks the aircraft the resolver cannot help with: on the AH-64D, 7 controls out of
478 have a position value known to the files — handling them gives you all the others.

The other way round, `--control "transfer pump"` boxes the control in your cockpit before it starts
watching, so you can check at a glance that your wording points at the right thing — or simply find
it.

Same conditions as verification: DCS on this machine, `dcs-serve` running, the bridge in the
mission. And like it, **the tool never moves anything**: it boxes, you handle.

#### Verifying a checklist in the cockpit {#verify}

A value the resolver wrote stays a hypothesis until the control has been read with the switch
physically in the wanted position. This command does that, with you at the controls:

```bash
veaf-tools cockpit verify-checklist checklists/my-checklist.yaml --write
```

For each measurable step the tool **boxes the control in your cockpit** and waits for you to move
it. As soon as the value changes and settles, it reads it and compares it with the checklist's. You
stay at the controls throughout: **the tool never throws anything itself**, it only boxes — which is
also handy when you cannot find the control.

`--write` marks the confirmed steps `verified: true`, so a later run does not redo them.

Three conditions: DCS runs **on this machine** (the read goes through `Export.lua`, which is local),
`dcs-serve` is running, and the mission embeds the bridge. A value read different from the expected
one is flagged in red: that is the interesting case, and it means the checklist has the wrong value.

### Which validation mode to choose {#validation-modes}

A step validates in one of three ways, and the choice depends first on **where your mission will
run**.

| Mode | What is read | Multiplayer |
|---|---|---|
| `argument` | the position of a cockpit control | **solo and local training only** |
| `param` | a value the aircraft publishes (altitude, speed, gear) | anywhere |
| `confirm` | nothing: the pilot ticks it | anywhere |

**The rule, in one sentence: if your mission is meant for the server, do not use `argument`.** That
read goes through `Export.lua`'s environment, which runs on the pilot's machine; from a dedicated
server it probably will not work — this is not verified yet. Nothing breaks either way: the step
simply never ticks itself and the pilot uses "Skip".

The resolver produces `argument` wherever it can, because a start-up checklist is flown alone first.
For a server mission, turn those steps into `confirm` — delete the `argument` and `equals` lines and
write `confirm: true`.

## Format reference {#format-reference}

This part describes the technical fields. You do not need it to write a checklist: it is for reading
a resolved file, or hand-writing a step the resolver refused.

### The fields of a step {#write-a-checklist}

One file per checklist, in `checklists/` beside your `mission.yaml`. An `id` that matches a shipped
checklist **overrides** it.

```yaml
id: f16c-startup              # unique; this is the override key
title: F-16C engine start     # i18n catalog key, or plain text
aircraft: [F-16C_50]          # DCS type names; an unknown type is rejected
menu: cold-start              # slot under "Assistance"

steps:
  # Pilot-validated: the element is boxed to show where to look
  # (`label` also accepts {fr: …, en: …} — see below)
  - label: MAIN PWR switch to MAIN PWR
    element: PTR-ELEC-TMB-MPWR-510   # cockpit element to box
    confirm: true

  # Automatically validated: a value the aircraft publishes is read
  - label: Gear down
    param: BASE_SENSOR_NOSE_GEAR_DOWN
    equals: 1.0                      # target value…
    tolerance: 0.05                  # …within this tolerance (0.05 by default)

  # Wide window: range replaces equals + tolerance
  - label: Speed between 250 and 300 kt
    param: BASE_SENSOR_IAS
    range: [128.0, 154.0]
```

Things to keep in mind:

- **A `label` (and the `title`) can be written three ways**:

  | Written | Meaning |
  |---|---|
  | `label: assist.f16c.main_pwr_batt` | a VEAF catalog key — what the shipped checklists use |
  | `label: MAIN PWR switch to BATT` | plain text, one language |
  | `label: {fr: MAIN PWR sur BATT, en: MAIN PWR switch to BATT}` | your own translations, written in place |

  The mapping form is resolved **at build time**, in the mission's language — the same one the
  picture is rendered in, so the two cannot disagree. A missing language falls back to French, then
  to any translation present: a label in the wrong language beats no label at all.
- **`element` is independent of the validation mode**: a gauge can be boxed while the pilot is the
  one who says it is good.
- **Three ways to validate a step**: `argument` (a control's position), `param` (a value the
  aircraft publishes), or nothing at all — then the pilot ticks it. A step declares exactly one.
- The **default tolerance of 0.05** suits the values that read 0 or 1. For an altitude or a speed,
  give your own `tolerance`, or a `range`.
- A mistake in the file **fails the build** with a message naming the offending file, rather than
  producing a Lua error in game.

### Iterating on a checklist without redoing the whole start-up {#dev-condition}

Checking step 30 of an engine start normally means performing the 29 before it, in a cockpit. That is
what makes iterating on a checklist tedious enough to discourage fixing small things.

Hence `dev_condition`, a **development hatch**: the step passes without the cockpit ever being in the
required state.

```yaml
- label: MAIN PWR to BATT
  element: PTR-ELEC-TMB-MPWR-510
  argument: 510
  equals: 1.0
  dev_condition: true    # absent from a shipped checklist
```

Put it on the steps you want to skip — typically 1 to 29 — and leave the one you are testing alone: when
the session opens, the assistance ticks the hatched steps and stops on yours.

**It is not a validation mode**: the step keeps its `argument`/`param`/`confirm`. The hatch
short-circuits the evaluation rather than replacing the measurement, so you can remove it without
rewriting anything.

Three guards, because a hatched checklist reaching production would tell a pilot they did something they
did not:

- **Absent means today's behaviour**, exactly. And `dev_condition: yes` or `dev_condition: 1` are
  **refused**: only `true` and `false` are accepted, so a typo cannot open the hatch.
- **The build warns you**, naming the checklist and the number of every step involved. It does not
  refuse: otherwise you could not build the mission you wanted to try in the first place.
- **The pilot sees it on screen** when the checklist starts: "⚠ N step(s) tick themselves". That is the
  guard which depends on nobody reading a log.

### Reading a switch position: `argument` {#switch-reading}

```yaml
  - label: MAIN PWR switch to MAIN PWR
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510        # the control's animation argument
    equals: 1.0
    tolerance: 0.05
```

The trailing number of an element name **is** the argument: `PTR-ELEC-TMB-MPWR-510` → `510`.

**Which value for which position?** It cannot be worked out from the hint: the F-16C's MAIN PWR
reads `MAIN PWR/BATT/OFF` and runs +1 / 0 / −1 — the other way round — while `OFF/BACKUP` runs
0 / 1. The only reliable source is the aircraft's own **keyboard and joystick bindings**, which
state the position-value pair outright: `MAIN PWR Switch - OFF` sets −1, `- BATT` sets 0,
`- MAIN PWR` sets +1. That is exactly what the [resolver](#instructor-path) reads for you; writing
a `control` spares you this whole paragraph.

**⚠️ Multiplayer caveat**: this mode is for solo and local training only — see
[Which validation mode to choose](#validation-modes).

**Two cases where `argument` will not work anyway:**

- a **spring-loaded switch** (`springloaded_*` in `clickable_defs.lua`, like the F-16C's JFS) is back
  at neutral before anything reads it;
- a **button** is not a position: the F-16C's argument 757 is the throttle's cut-off finger lift, not
  the throttle's position.

Measurements and details:
[DCS cockpit + picture API](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md).

### Find a `param` {#find-a-param}

What can be read is a control's **effect**, not the control. On an F-16C on the ramp, 78 values are
published, among them:

| Parameter | What it holds |
|---|---|
| `BASE_SENSOR_NOSE_GEAR_DOWN` | `1` nose gear down |
| `BASE_SENSOR_WOW_LEFT_GEAR` | `1` weight on the left wheel |
| `BASE_SENSOR_CANOPY_POS` | canopy opening, `0` to `1` |
| `BASE_SENSOR_FLAPS_RETRACTED` | `1` flaps retracted |
| `BASE_SENSOR_IAS` | indicated airspeed (m/s) |
| `BASE_SENSOR_BAROALT` | barometric altitude (m) |
| `BASE_SENSOR_HEADING` | heading (radians) |
| `BASE_SENSOR_FUEL_TOTAL` | fuel remaining |

The list is per aircraft: each module publishes what it wants. To see yours, call
`list_cockpit_params()` in the mission environment — it returns one `NAME:value` per line.

### Find the element to box {#find-element}

**The easy way is to write a `control` and let [the resolver](#instructor-path) find it**: it knows
the controls of every indexed aircraft (F-16C, A-10C II, AH-64D, F-14B and F-14B(U)) and gives you
the exact name.

For an aircraft that is not indexed, the name is read from the module's files, inside your DCS
installation:

```text
<DCS>\Mods\aircraft\<Aircraft>\Cockpit\Scripts\clickabledata.lua
```

Only **clickable** elements are listed there: a gauge or a warning light has no name to box.

You can also index that aircraft once and for all, and the resolver will handle it like the others:

```bash
veaf-build update-dcs-data --cockpit-controls --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

---

## What it costs {#cost}

The display rests on a picture embedded in the `.miz`, and DCS can only show an embedded resource.
The build therefore generates **one picture per progress state**: a twelve-step checklist is
thirteen pictures, on the order of 60 to 80 KB in total. A mission that activates no checklist pays
nothing.

The build reports the number of pictures and their total size, so the price is visible at the moment
it is incurred.

---

## Known limitation {#limitations}

Displayed progress is **linear**: the picture for step 5 shows the first four ticked. A step the
pilot **skipped** therefore appears ticked like any other. Representing "skipped" faithfully would
need one picture per combination of states, which explodes. The text message carries that exception.
