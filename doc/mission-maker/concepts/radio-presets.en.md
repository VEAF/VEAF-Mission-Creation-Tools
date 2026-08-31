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
