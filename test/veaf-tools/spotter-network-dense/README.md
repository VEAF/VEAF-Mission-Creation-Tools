# `spotter-network-dense` — the spotter network at a density you can read

A demonstration mission for `modules.SKYNET.spotter_network`, built to be **loaded and looked at**.
It needs no bridge, no script and no console: load it, open the F10 map, wait.

Its sibling `../spotter-network-walkthrough/` is the *discriminating* rig — the smallest layout in
which a wrong answer cannot be mistaken for a right one. This one is the *legibility* rig, and it
exists because ten groups do not show whether a picture stays readable.

## Loading it

Syria, anchored on **Palmyra**. Two ways in:

| Role | What you get |
|---|---|
| **Game Master, red** | the whole picture, nothing to fly. The simplest way to watch. |
| **`DemoSlot-Su25T`**, cold on Palmyra's ramp | a red Su-25T, so you have a group and a cockpit. The Su-25T ships free with DCS; if it does not appear in the slot list, the module is disabled in your DCS module manager. |

**Reopen the F10 map after the mission has loaded.** A scripted drawing does not appear on a map that
is already open — this is the single most common reason for "it draws nothing".

The map view is set to `spotter_view: "on"`, so it comes up by itself. There is nothing to switch on.

## What is on the map, and what each shape means

One shape set per **DCS group**: the square says what a node *knows*, the circle says what it can
*see*, and each colour means one thing only.

| Shape | Grey | Blue | Orange | Red |
|---|---|---|---|---|
| **Square** (the node) | has not been told | was told | — | element of a live battery |
| **Circle** (its range) | spotter seeing nothing | — | spotter holding a contact | live battery's firing envelope |

A dark battery draws **no** envelope at all. Plus a **red cross** on each held contact, a **grey
dashed** line for a radio link, and a **solid red** line for a link that actually carried an alert —
which is how the path of a report stays readable.

## The layout, and what each piece is there to show

| | |
|---|---|
| **six observation posts**, `OP-Alpha` … `OP-Echo` | a screen over 95 km of front, **17 km** apart against a 20 km radio range — so they form one chain |
| **`OP-Foxtrot-Isolated`** | **27 km** from the next one: out of radio range, an island on purpose. A network drawn without a visible island does not show that the range decides anything |
| **`Tadmor-*`**, seven groups inside 2.5 km | packed the way a combat zone is packed: armour, IFV, trucks, infantry, MANPADS, AAA and an Osa site |
| **`Arak-*`**, five groups | a Kub site, command trucks, infantry, a `1L13 EWR` — and `Arak-Shilka-And-Igla`, a **mixed** group: the Shilkas are blind and the Igla sees 10 km, so the group sees 10 km |
| **`Arak-EWR`** and **`AWACS-Mainstay`** | a square with **no circle**: they relay and see nothing |
| **`CAP-Fulcrum`** | two MiG-29 on a racetrack — the largest circle on the map, 30 km, and it moves |
| **`Helo-Hip-Patrol`** | two Mi-8, 15 km, also moving |
| **`Sukhna`** | a real VEAF combat zone: its five groups are **absent at start** and appear on activation |

## What happens on its own

1. **t = 0 to ~35 s — everything grey.** The graph fills in by speed class: the air patrols first
   (10 s), the vehicles next (20 s), the infantry last (30 s). That is `SpotterGraphPeriods`, not a
   delay to worry about.
2. **t = 120 s — the intruder enters from the north**, an F-15C flying down the screen at 150 m/s. It
   is made **invisible** to the DCS AI on purpose (see below), so nothing shoots it and the
   demonstration runs its course.
   * circles turn **grey → orange** as each post picks it up, north to south;
   * squares turn **blue** one hop at a time — the propagation, one hop per 20 s;
   * the links that carried the alert turn **solid red**;
   * `OP-Foxtrot-Isolated` stays grey throughout. Nobody can talk to it.
3. **The intruder hooks east**, to within **7.8 km** of `Tadmor-Osa` — inside its 10.3 km envelope.
   The Osa is blind (`SAM elements`, range 0), so it lights up on what a neighbour told it:
   **red square, red envelope**. Then the aircraft turns back out and the battery goes dark again.
4. **On the straight legs, `Arak-Kub` gets its own turn**: it sits 22 km from the corridor and a Kub
   reaches 25 km.

Every other battery holds the contact and stays grey, with no envelope — the aircraft never enters
*its* envelope. That is the feature's whole point: the spotter network is a **distributed
early-warning radar**, not a wake-up trigger.

## The combat zone

**F10 → VEAF → ZONES DE COMBAT → Sukhna → Activer la zone.** Five groups appear in the south-east and
the graph links them to `OP-Echo` at the next pass of their class — up to 30 s later, because a group
that appears mid-mission detects immediately but cannot relay until it is in the graph.

The zone carries `radio_menu_coalition: ALL`, and it has to. Without it, a combat zone's F10 menu goes
to the coalition **friendly to the zone** — the side that attacks it — so a zone full of red units is
a *blue* objective and a red viewer sees the `ZONES DE COMBAT` root with nothing inside it.

## Two things not to change without knowing why

* **The intruder is invisible, never immortal.** A SAM site goes live because it was *told*, not
  because it can see, so an invisible target lights the network up while no AI engages it. An
  immortal one does the opposite: a battery empties its magazine into something that cannot die, and
  a site with no ammunition **never goes live again**. Weapons hold is not an alternative either —
  Skynet sets ROE back to free whenever it brings a site live.
* **The intruder must not look like a HARM.** Skynet classifies a contact over 800 kt with at most two
  changes of flight path as an anti-radiation missile and sends the sites into evasion. Hence 150 m/s
  and an altitude profile with several changes.

## The numbers, and why this mission exists

Measured in game on 2026-09-21, with the same layout counted both ways:

| | per group (what it does) | per unit (what it used to do) |
|---|---|---|
| graph nodes | **21**, then **26** with `Sukhna` active | 57, then 71 |
| links drawn | **65–67**, then **78–83** | 576, then 713 |
| shapes drawn | **103–135** | ~690–855, against a budget of **400** |

So this mission would have been **truncated by construction** before `FIX-SPOTTER-NODES-ARE-GROUPS`:
the links alone exceeded the draw budget and everything after them was silently dropped. Each
11-vehicle convoy was contributing eleven overlapping circles, eleven stacked squares and 55 links to
itself.

## Building it again

```bash
poetry run veaf-build build --skip-python --version <x.y.z> --output <scratch>
poetry run veaf-tools mission build SpotterDense . --dev-mode --scripts-path <repo root>
```

Then **delete the `build:` block the build writes back into `mission.yaml`** — it carries an absolute
path. And check the result by unzipping the `.miz` rather than by reading the sources: `--dev-mode`
reads the prebuilt `build/veaf-scripts.lua`, so a mission built before the Lua package is a mission
without your change in it.
