# Lot FEAT-KNEEBOARD-PRESETS-REDESIGN — a radio presets kneeboard page DCS shows undistorted

Status: ✅ done
Branch: feature/kneeboard-presets-redesign → PR → develop

## Problem Statement

The presets kneeboard page (`RadioPresetsImageGenerator`) is landscape, 1200 px wide, with a height that depends on the aircraft (665 px for the Mi-24P, 785 for the Hornet, 1085 for the A-10C II).
DCS maps a kneeboard image onto the whole kneeboard window with texture coordinates 0..1 (`Scripts/Aircrafts/_Common/Cockpit/KNEEBOARD/indicator/init.lua`, `image_page_template`): it never keeps the image's proportions.
The cockpit kneeboard measures 0.142 × 0.214 (`declare_kneeboard_device.lua`), a 2:3 portrait, and the default 2D window measured on David's screenshot (2026-10-18) is 2:3 too.
So the page is squashed to about 60 % of its width in game, and a pilot who resizes the window distorts it further — the window is customisable.

The page also titles each radio with the packer's role (`primary_1`, `fm_supplement`) instead of the cockpit set (`COMM 1: ARC-210`), titles the page with the raw DCS type (`FA-18C_hornet (blue)`), draws every radio as tall as the tallest one (21 empty rows on the A-10C II's VHF), and uses an 18 px font on a pale yellow background.

## Solution

Redraw the page from scratch, validated by David on a mock-up (2026-10-18):

- a fixed 1536 × 2304 portrait page, the 2:3 of the kneeboard, twice the definition of ED's 768 × 1024 pages so it stays sharp in VR;
- a header with the aircraft's readable name and a coalition badge;
- one block per radio, titled with its number and the cockpit set from `dcs-radio-specs.yaml`, with its band; a layout may override that title (`kneeboard_title`, the Viggen's `FR22 / FR24`);
- CH / name / MHz columns, plus AM/FM when the radio carries both; a block stops at its last channel, inner gaps stay;
- blocks flow into two columns, a block moving whole to the next column rather than being split when it fits there, and onto a second page only when the page is full;
- one shared calibration page (`KNEEBOARD/IMAGES/00-veaf-calibration.png`) telling the pilot to resize the window until its circles are round — no target on the presets pages themselves (David, 2026-10-18);
- every text on the page goes through the locale files.

## User Stories

1. As a pilot, I want the presets page to read undistorted in the default kneeboard window and in VR, so that I can read a frequency at a glance.
2. As a pilot, I want each block titled with the radio I have in the cockpit, so that I know which set to tune.
3. As a pilot who resized the kneeboard window, I want a target that shows the distortion, so that I can put the window back to the right proportions.

## Implementation Decisions

- The page size is fixed: DCS stretches whatever it gets, so the only right size is the window's default ratio.
- The radio heading comes from the specs by physical position (the same order `PresetDefinition.to_dict` injects), falling back to the radio's own title for a type the specs do not know.
- The Viggen's display name lives in `dcs-radio-layouts.yaml` (`kneeboard_title`), not in the generated specs: renaming the specs radio would break `add_ranges`, which names it.
- The calibration page is emitted once per mission, only when at least one presets page is.
- A page that overflows is written `presets_2.png` (or `presets-<coalition>_2.png`): `_` sorts after `.`, so it follows `presets.png` in a name-ordered folder; the first page keeps its current name.

## Out of scope

- The 30 nameless FM channels of the shipped `fm_supplement` list: the page shows what is injected.
- Telling the pilot how to resize the window: the calibration page's instruction stays generic.
