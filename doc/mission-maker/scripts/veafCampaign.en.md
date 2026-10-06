# veafCampaign — Multi-mission campaign

**Module ID:** `CAMPAIGN` | **File:** `veafCampaign.lua`

---

## Purpose

Runs **one mission** of a campaign flown mission after mission: it spawns the campaign's garrisons minus their losses, shows the situation on the F10 map and in a radio menu, handles the capture of neutral zones by ground presence, and writes the state file the next mission will start from.

The campaign itself — declaring it, its state, moving from one mission to the next — is run with the `veaf-tools campaign` commands: see [Multi-mission campaign](../CAMPAIGN.en.md).

---

## Activation

The module is not configured by hand: `veaf-tools campaign next` turns it on in `mission.yaml` and writes its data to `src/campaign-data.yaml`.

```yaml
modules:
  CAMPAIGN:
    enable: true
    data_file: src/campaign-data.yaml
```

At build, the content of `data_file` becomes the `veafCampaign.data` table, set just before `veafCampaign.initialize()`.
Without data (the file is missing), the module says so in `dcs.log` and does nothing.

---

## What it does in game

| when | what |
|---|---|
| at start | every campaign airfield goes to its owner, DCS's own capture turned off; the garrisons never drawn are drawn; all of them spawn minus their losses |
| every 10 s | neutral zones are checked for capture; the map is redrawn where something changed |
| every `state_write_seconds` | the state file is written |
| when a garrison unit is lost | the loss is recorded; a zone left without a garrison turns neutral |
| at mission end | the state file is written one last time |

One loop for the whole module, no timer per zone.

---

## Radio menu

**Campaign → Situation**: the zones with their owner and their garrison's strength, the captures in progress, the objectives, the mission number.

**Campaign → Counters (admin)**: beats, zones visited, drawings, units spawned, losses handled, state writes — enough to check that the module is working.

---

## State file

`<Saved Games>\DCS\Missions\Saves\<campaign>\mission-NN.state`, a Lua table (`return { … }`) that `veaf-tools campaign apply` reads back.
It needs `io` and `lfs` in the mission scripting environment; `os` is used when it is there, not required.
See [the state file](../CAMPAIGN.en.md#state-file).
