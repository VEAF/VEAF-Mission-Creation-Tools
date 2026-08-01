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
    checklists: [f16c-cold-start]   # the checklists this mission activates
```

- **With a `checklists:` list**: exactly those. An unknown `id` fails the build, rather than leaving
  a menu entry silently missing.
- **With no list**: the checklists you dropped in your mission's `checklists/` folder are activated.
  **Never the whole shipped catalogue** — every activated checklist embeds one picture per step in
  the `.miz`.
- **Module absent or `enabled: false`**: nothing is loaded, nothing is generated, no image in the
  `.miz`.

### Write a checklist {#write-a-checklist}

One file per checklist, in `checklists/` beside your `mission.yaml`. An `id` that matches a shipped
checklist **overrides** it.

```yaml
id: f16c-startup              # unique; this is the override key
title: F-16C engine start     # i18n catalog key, or plain text
aircraft: [F-16C_50]          # DCS type names; an unknown type is rejected
menu: cold-start              # slot under "Assistance"

steps:
  # Pilot-validated: the element is boxed to show where to look
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

- **A `label` may be a sentence**, not necessarily a catalog key: an unknown key comes back
  unchanged, so you can simply write your own text.
- **`element` is independent of the validation mode**: a gauge can be boxed while the pilot is the
  one who says it is good.
- **A `param` means automatic validation**; with no param, the pilot validates.
- The **default tolerance of 0.05** suits the values that read 0 or 1. For an altitude or a speed,
  give your own `tolerance`, or a `range`.
- A mistake in the file **fails the build** with a message naming the offending file, rather than
  producing a Lua error in game.

### A switch position cannot be read {#no-switch-reading}

This is the module's defining limit, and it was **measured in game**: a mission script cannot see
where a cockpit control is. An F-16C's MAIN PWR switch was moved through all three of its positions
without any of the three available mechanisms budging. The cockpit is a separate model and its state
does not reach the mission; ED's own training checklists manage it because their code runs *inside*
the module's cockpit, which is closed to us.

In practice: **a "set this switch to that position" step is validated with `confirm`**. That is the
case for all six steps of the shipped F-16C checklist.

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

It is read from the aircraft module's files, inside your DCS installation:

```text
<DCS>\Mods\aircraft\<Aircraft>\Cockpit\Scripts\clickabledata.lua
```

Only **clickable** elements are listed there: a gauge or a warning light has no name to box.

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
