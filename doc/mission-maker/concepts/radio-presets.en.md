# Radio presets

## What it is {#what-it-is}

`src/presets.yaml` describes the radio channels **once per coalition**, and the build projects them
onto the physical radios of every player aircraft. It also renders one kneeboard PNG per aircraft
type into the `.miz`.

No more setting channels one by one, aircraft by aircraft, in the DCS editor.

## The smallest example that works {#minimal-example}

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

channel_lists:
  blue:
    primary_1:
      01: Guard
```

- `channels_collection` gives a **name** to a frequency, with one value per band.
- `channel_lists` declares, per coalition and per **radio role**, which channel goes on which number.

A literal frequency needs no `channels_collection`:

```yaml
channel_lists:
  blue:
    primary_1:
      01: 251.0
```

## The radio roles {#radio-roles}

| Role | Band | Used for |
|---|---|---|
| `primary_1` | UHF | the first V/UHF radio |
| `primary_2` | VHF | the second V/UHF; also the warbirds' single radio |
| `fm_supplement` | FM | FM on top of two V/UHF radios (A-10C…) |
| `fm_substitute` | FM | FM in place of a V/UHF |
| `fm_secondary` | FM | a second FM |

The build looks at each aircraft type's real radios and gives them the matching role. An unknown
role fails the build.

## The gotcha {#gotcha}

**A channel with no frequency in the role's band is dropped, silently.** A channel declaring only a
`uhf:` value placed under `primary_2` (VHF) disappears from the projected list — that channel number
stays empty on the radio. A literal frequency, on the other hand, is never dropped.

The symptom to watch for: `presets-validation-report.md` appearing at the root of the mission folder
after a build. It is only written when something is wrong, and deleted once nothing is.

## A radio has a capacity {#capacity}

A cockpit radio holds a fixed number of presets, and a longer list is **cut at the end, with a warning at build**.
The cut goes by channel number: a channel dropped from a list (out of band) leaves its slot empty so that a pilot's channel N stays N, so the channels past the last slot go, and the others keep their number.
The build gives one warning for every radio it cut, naming for each the type, the radio, its capacity and how many channels were dropped: those are channels a pilot will not find in the cockpit.
The cut applies to the presets assigned by hand in `presets_assignments` too: the shipped blue CH-47F gets only the first 20 channels of `radio_fm_30`, the list itself staying at 30.

Example: the OH-58D Kiowa's two FM radios hold 21 presets, `C`, `M` then 1 to 19.
A 30-entry `fm_supplement` gave them 32, and the DCS client crashed at spawn in multiplayer; the build now stops them at 21.
For the Kiowa to get the whole list, keep FM lists at 20 entries or fewer.

Every radio of every aircraft has its capacity: the channel count the aircraft's module declares itself, in its `panelRadio` table.
Warbird radios hold few (4 on the P-51D, 5 on the Spitfire), the AH-64D 10 per radio: a list the whole coalition shares is cut there, and the build says so.
Those counts are read from the DCS datamine (`dcs-radio-specs.yaml`, field `channels`) and are refreshed with the rest of the radio data after a DCS update, by `veaf-build update-dcs-data --radio`.
A few aircraft declare none (Flaming Cliffs, the La-7, the MiG-15bis): their lists go through whole.

## The kneeboard {#kneeboard}

Each aircraft type gets its page `KNEEBOARD/<type>/IMAGES/presets.png`: one column per radio, titled with the cockpit set (`1. COMM 1 · ARC-210`) and its band, then the channel number, the name and the frequency.
A radio stops at its last channel; a page that is not enough continues on `presets_2.png`.

DCS **stretches the image to fill the kneeboard window**, whatever its proportions.
The pages are drawn at 2:3, the shape of the cockpit kneeboard and of the default window.
A pilot who resized the window sees the pages distorted: the `00-veaf-calibration.png` page, added to every mission that has kneeboards, is the test pattern — resize the window until its circles are round.

## Going further {#more}

- An explicit per-type assignment under `presets_assignments:` **always wins** over the automatic
  projection — including `none`, which leaves the group's radios untouched.
- To keep the radio injection but skip the kneeboards:

  ```yaml
  pipeline:
    presets:
      enabled: true
      kneeboards: false
  ```

- [Pipeline reference — step 1, radio presets](../../PIPELINE_REFERENCE.en.md#pipeline-step-1-presets)
- [Pipeline reference — the two authoring formats](../../PIPELINE_REFERENCE.en.md#two-authoring-formats)
- [DCS radio specs](../dcs-radio-specs.en.md) — what each aircraft actually carries
