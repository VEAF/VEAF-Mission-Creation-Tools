# FEAT-FOOTHOLD-PRESETS-PLAN — move the Foothold `presets.yaml` to the preset-plan model

Status: ⬜ ready

## Context

David carries a `presets.yaml` written for an earlier v6 and copied into all ten Foothold
mission folders (`src/presets.yaml`, ~17.6 KB). Question asked: does it still hold up, and
should it be converted?

**It holds up.** Verified by building an adopted `Foothold_AF_2.4.1` with that exact file on
6.11.4: the presets are injected, 30 kneeboard pages are produced, no error. And by
construction — [ADR 0010](../../docs/adr/0010-per-type-radio-preset-projection.md) states the
two authoring formats coexist "**indefinitely** […] **No deprecation**". The file uses the older
layers (`radios_collection` → `presets_collection` → `presets_assignments` +
`channels_collection`), which remain the supported manual-override path.

Note that `veaf-tools validate` says nothing about this: it does not check the `presets.yaml`
schema, so its `✓` is not evidence either way. The build's own
`presets-validation-report.md` is where the answer is.

## What the report actually says

**10 aircraft types receive channels outside their radios' bands**, silently removed from the
injected presets (DCS would store them and ignore them):

| Type | Why |
|---|---|
| AJS37, F-4E-45MC, M-2000C, MiG-21Bis, MiG-29 Fulcrum, Mirage-F1BE, Mirage-F1CE, Mirage-F1EE, Ka-50_3, UH-1H | `presets_assignments.blue.*.all: modern_blue_uhf_vhf_fm` gives every type a 30-60 MHz FM radio; these types have no radio on that band |

For the AJS37 the whole 30-channel FM list is dropped. The report even suggests the manual
workaround (`AJS37: none`), which is the shape of the problem: the current model needs one
hand-written collection, or one exclusion, per airframe quirk.

The file already carries six hand-made collections for exactly that reason — inverted A-10
(`modern_blue_vhf_uhf_fm`), CH-47 FM-first, OH-58D two FMs, Apache, Gazelle — plus three types
given up on entirely: `Mi-8MT: empty`, `Mi-24P: empty`, `MiG-15bis: empty`.

**This is the case ADR 0010 was written for.** In the preset-plan model the mission-maker
declares a handful of Channel lists per Radio role, and a VEAF-maintained per-type Radio layout
projects them onto each airframe's physical radios — channel-0 rotation, reserved slots, radio
fusion, per-channel modulation included. The A-10, Apache, Gazelle, OH-58D and Mi-24P stop being
the maker's problem, and out-of-band channels stop being produced at all.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Rewrite the Foothold presets as a preset plan](tickets/01-rewrite-as-preset-plan.md) | ⬜ |

## Decision needed before starting

**Hand-write the plan, or build a legacy→plan converter?** There is no migration tool today:
`convert-v5` generates a plan from a **v5 mission's** `radioPresets*` tables, which does not
apply here — this is a v6 file in the old format.

Recommendation: **hand-write it.** The source is small and regular (three channel lists —
UHF/VHF/FM — plus a couple of special collections), it is one file reused across the ten
missions, and the result must be read and approved by a human anyway. A converter would be more
code than the thing it converts, for a migration VEAF performs once.

Ticket 01 assumes the hand-written route; say so if a reusable converter is wanted instead, and
it becomes a different ticket.

## Out of scope

- **Deprecating the old layers.** ADR 0010 is explicit that both formats stay. Nothing here
  removes or discourages the legacy path for other missions.
- **`ENRICH-DEFAULT-PRESETS`** (the shipped default `presets.yaml`, pending a session with
  Tripack) is a separate lot. This one is about the Foothold missions' own file — though
  whatever is learned here should inform it.
