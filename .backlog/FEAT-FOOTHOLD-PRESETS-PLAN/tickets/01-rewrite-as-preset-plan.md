# 01 — Rewrite the Foothold presets as a preset plan

Status: ✅ done
Type: feat

## Why

See the [PRD](../PRD.md): the current file works, but hands ten aircraft types channels their
radios cannot receive, and needs a hand-written collection per airframe quirk. The preset-plan
model removes both problems.

## Target shape

Three `channel_lists` roles replace the six collections, following
`src/defaults/mission-folder/src/presets.yaml`:

| Role | From the current file | Notes |
|---|---|---|
| `primary_1` | `radio_uhf_30` | first V/UHF radio |
| `primary_2` | `radio_vhf_30` | second V/UHF; also the warbirds' single radio |
| `fm_supplement` | `radio_fm_30` | FM atop two V/UHF (attack aircraft) |
| `fm_substitute` | — | FM as **2nd** radio (helicopters); decide whether the FM list is reused as-is |

`channels_collection` is kept unchanged — it is the frequency source and is orthogonal to the
authoring model.

## Tasks

- [x] Write the `channel_lists` block for `blue` from the three existing radios, preserving
      channel numbers and titles (they appear on the kneeboards).
- [x] Decide `fm_substitute` (helicopter FM-as-second-radio): same list as `fm_supplement`, or
      a shorter one. The current file's CH-47 collection (`modern_blue_fm_uhf`) is the clue.
- [x] Drop the collections the packer now covers, and **check each against the report** rather
      than assuming: A-10C_2 (inverted), CH-47Fbl1, AH-64D_BLK_II, OH58D, SA342* (Gazelle).
- [x] Revisit the three `empty` assignments (`Mi-8MT`, `Mi-24P`, `MiG-15bis`): the packer knows
      the Mi-24P channel-0 rotation, so `empty` is likely no longer needed. `MiG-15bis` had its
      own fix (`FIX-MIG15-PRIMARY-FREQ`) — confirm what it needs now.
- [x] Keep `red: all: none` (Foothold's red side is AI).
- [x] Consider `priority`/`color` on the key channels (ADR 0012) — Guard, the tankers, the
      carrier — since they also drive the AJS-37 FR22 specials.
- [x] Build one mission with the new file and **diff `presets-validation-report.md` against the
      current one**: the out-of-band section must shrink to nothing, or every remaining entry
      must be explained.
- [x] Compare the generated kneeboards before/after on two or three types (a plain one, the
      Apache, the AJS-37) — the plates are what players actually read.
- [x] Roll the file out to the ten Foothold mission folders.
- [x] CHANGELOG + version bump.

## Verify

The acceptance criterion is the **report**, not the absence of errors: today's build is already
error-free while dropping 30 AJS-37 channels. Success is the out-of-band list going away, with
the kneeboards still showing the channels players expect.

## Notes

Do this on **one** mission first and get it reviewed before copying to the ten folders — the
same file is reused everywhere, so a mistake multiplies by ten.
