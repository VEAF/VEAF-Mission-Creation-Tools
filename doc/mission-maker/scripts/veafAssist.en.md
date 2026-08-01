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
  # Automatically validated: a cockpit animation argument is read
  - label: MAIN PWR switch to MAIN PWR
    element: PTR-ELEC-TMB-MPWR-510   # cockpit element to box
    argument: 510                    # animation argument to read
    equals: 1.0                      # target value…
    tolerance: 0.05                  # …within this tolerance (0.05 by default)

  # Pilot-validated: the element is boxed anyway, to show where to look
  - label: JFS RUN light on — check
    element: PTR-ENGSTART-TMB-JETFUEL-447
    confirm: true

  # Wide window: range replaces equals + tolerance
  - label: Throttle between IDLE and MIL
    argument: 757
    range: [0.2, 0.9]
```

Things to keep in mind:

- **A `label` may be a sentence**, not necessarily a catalog key: an unknown key comes back
  unchanged, so you can simply write your own text.
- **`element` is independent of the validation mode**: a gauge can be boxed while the pilot is the
  one who says it is good.
- **An `argument` means automatic validation**; with no argument, the pilot validates.
- **A spring-loaded switch** (one that returns to neutral by itself) cannot be caught by its
  argument: use `confirm: true`.
- A mistake in the file **fails the build** with a message naming the offending file, rather than
  producing a Lua error in game.

### Find the element and the argument {#find-element-and-argument}

Both are read from the aircraft module's files, inside your DCS installation:

```text
<DCS>\Mods\aircraft\<Aircraft>\Cockpit\Scripts\clickabledata.lua
```

The trailing number of an element name **is** the animation argument:
`PTR-ELEC-TMB-MPWR-510` → argument `510`.

The **window**, however, has to be measured: a three-position switch may run `0` to `1` or `-1` to
`+1`. Read the value for **every** position, not just the one you want, and pick a tolerance narrow
enough to reject the neighbouring position.

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
