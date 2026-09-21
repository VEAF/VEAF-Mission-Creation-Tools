# Spotter-network rig (Syria)

The mission that answers **does a report travel from the unit that saw the aircraft to a battery that
never did?** — the one question [`FEAT-SPOTTER-NETWORK`](../../../.backlog/archive/FEAT-SPOTTER-NETWORK.md)
had left open, and which no unit test can settle because the answer is made of DCS detection,
terrain and time.

It is a **rig**, not a demonstration: it is built so the answer cannot be mistaken for something
else, and it is driven from outside without anybody flying. The demonstration layer — the map view,
the last line of defence shown on its own, a mission a human enjoys flying — comes after, and is
deliberately not here.

## Why the obvious mission does not work

Two facts, measured in the code rather than assumed, killed two earlier designs:

**A battery with no early-warning radar is not dark — it is permanently live.** A SAM site is built
with `isAutonomous = true` and an autonomous behaviour of `AUTONOMOUS_STATE_DCS_AI`
(`skynet-iads-compiled.lua:3014`), so with no EWR to parent it, it hands itself to the DCS AI and
lights up. "No EWR, so the only way to wake is the relay" produces the exact opposite of what it
promises: everything lit, from the first second, including the control.

**The site's own state cannot attribute the wake-up.** Whether a battery is live says nothing about
*why*. With an EWR present it may have been informed by the radar; without one it is autonomous. The
only thing that names the relay as the cause is the hand-over's own record.

So the rig reads **`veafSkynet.getSpotterWakeUpLog(coalition)`**, the durable history added by this
lot. Its predecessor, the status page's bucket, is drained on every cycle — reading that from outside
races the drain and reports a false negative.

## The geometry, and what each distance is for

All positions are mission-table coordinates, where **`x` is the northing and `y` the easting** — see
[`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md), because the same three
letters mean something else at runtime and getting it wrong raises no error.

| Object | Position | Type |
|---|---|---|
| `SpotterIgla` — red | `(-40220, 405386)` | `SA-18 Igla-S manpad` |
| `NetworkSa6` — red | `(-50220, 405386)` | `Kub 1S91 str` + 2× `Kub 2P25 ln` |
| `ControlSa6` — red | `(-50220, 465386)` | same, 60 km east |
| target point | `(-32220, 405386)` | the anchor where DCS reliably processes events |

```
  target ──8 km──► SpotterIgla ──10 km──► NetworkSa6          ControlSa6
  (18 km from NetworkSa6)                                     60 km east
                   ◄────── radio range 20 km ──────►          ◄── out of reach ──►
```

| Distance | Why exactly that |
|---|---|
| target → `SpotterIgla` = **8 km** | under the Igla's **10 km** of eyes. Measured, not chosen: `SA-18 Igla-S manpad` matches the `MANPADS` row of `veafSkynet.SpotterUnitTable`, and the profile lookup takes the **first** matching row — a Shilka or a Roland matches `SAM elements` first and is **blind**, so neither can be a spotter |
| `SpotterIgla` → `NetworkSa6` = **10 km** | under the 20 km radio range, so the word travels |
| target → `NetworkSa6` = **18 km** | inside a Kub's firing envelope (~24 km), so the site *can* go live on the contact |
| `ControlSa6` at **60 km** | three times the radio range: no report can reach it, by construction |

## The last line of defence is OFF, and that is the point

`last_line_of_defence: false` in `mission.yaml`. With it on, a dark site keeps a detection radius of
its own drawn **at random between 10 and 15 km** — and `NetworkSa6` sits 18 km from the target point.
Whether the site had lit up on its own radius or on a relayed contact would then depend on a dice
roll made at mission start. **A rig whose verdict comes from a draw is not a rig.**

The demonstration layer turns it back on, on purpose, to show the other behaviour.

## Build it

```bash
veaf-tools mission build SpotterDemo . --dev-mode --scripts-path <repo root>
```

`dev_mode` and `scripts_path` are deliberately **not** persisted in `mission.yaml`: a build writes
them there, and `scripts_path` is an absolute path on whoever ran it. Pass them on the command line.

`veaf-tools mission validate .` is clean as shipped. `security.disabled: true` sits at the **root**
of `mission.yaml` — a password prompt makes a rig nobody can run unattended.

## Run it

The DCS bridge is injected (`dcs_bridge: enabled: true`), so the measurement needs no pilot:

1. load `SpotterDemo_<date>.miz` in DCS;
2. put a hostile aircraft near the target point — fly the `SpotterDemoPlayer` slot (A-10C_2, parked
   cold at Bassel Al-Assad), or spawn one through the bridge;
3. leave it a minute: detection runs every 5 s and one radio hop takes 20 s at the shipped settings;
4. with `dcs-serve` up on `127.0.0.1:8080`:

```bash
veaf-tools smoke-test --suite spotter
```

## What the two checks say

| Check | Passes on | What it means |
|---|---|---|
| `spotter-relay-reached-the-network-battery` | `woken:` ≥ 1 | a report crossed 10 km of radio and named a battery that has no eyes of its own — the feature working |
| `spotter-relay-did-not-reach-the-control-battery` | `woken:0` | the 60 km battery was never named. **This is the half that lets the other one fail**: a run where both are woken is measuring something other than the relay |

Other answers are legible rather than silent: `veaf-absent` (the scripts did not load),
`no-spotter-history` (a build predating this lot), `no-such-site` (this is not the rig mission).

## The honest limit of this rig

It proves **the report travelled and named the right battery**. It does not prove the battery *went
from dark to live because of it*: with no EWR the batteries are autonomous and already live, and the
hand-over records the wake-up all the same. Making a battery genuinely dark requires an EWR, and an
EWR that covers it may also be the one that informs it — which is why that part belongs to the
demonstration layer and to a human reading the log, not to an automated check.

Said here rather than left to be discovered, because a rig whose limits are not written down is read
as proving more than it does.
