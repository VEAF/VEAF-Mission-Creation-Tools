# FEAT-CTLD-SLINGLOAD-TOGGLE — no way to turn CTLD sling loading on or off in flight

Status: ⬜ ready

Origin: [#60](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/60), 2021.

## The gap

The ask is a command to enable or disable CTLD sling loading. Grepped: no `sling` toggle anywhere in
the radio layer.

The reason it matters is practical rather than technical — sling loading changes how a helicopter crew
plays a mission, and a game master pacing a training wants to switch it without editing a file and
rebuilding.

## Scope

A radio entry under the CTLD menu, toggling CTLD's own sling-load flag at runtime.

Cheaper than it was in 2021, and for a reason worth knowing: CTLD 2 is configured by the mission's
`ctld-config.yaml` (ADR 0016) and is now genuinely initialised
(`FIX-CTLD-NEVER-INITIALIZED`), so there is a live, configured CTLD to talk to. Two things to settle
by reading CTLD 2 rather than CTLD 1:

- **Which flag.** CTLD 1's name for it may not have survived the migration — the stale-comment trap
  that made #72's first verdict wrong.
- **Whether flipping it mid-mission is honoured** or only read at startup. If it is startup-only, the
  answer is a `ctld-config.yaml` key plus a clear message, not a radio toggle that lies.

## Definition of done

- [ ] Sling loading can be switched from the radio menu, or — if the runtime only reads it at startup —
      a config key ships instead, and the toggle is **not** faked
- [ ] Which of those two it is, recorded here with the CTLD 2 evidence
- [ ] The menu label localised (`FIX-RADIO-MENU-I18N` made that the rule)
- [ ] Documented, both languages
