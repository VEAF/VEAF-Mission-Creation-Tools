# 02 — Declare them, default FM list to 20

Status: ✅ done

## Done when

- The injector applies the read capacities to every type (PRD D3); the existing OH-58D, Mi-24P and CH-47F values are unchanged or, if the read differs, the difference is explained.
- A build from the shipped defaults and from a sample of OT `presets.yaml` is byte-for-byte unchanged where nothing overflows (PRD D4, test).
- The default `fm_supplement` holds 20 entries and a default build raises no capacity warning (PRD D5, measured); `mission.yaml` defaults lockstep checked (CLAUDE.md §9 item 7).
- Presets doc page (fr, en) says capacities come from the modules and how to refresh them; `known-limitations.yaml` entry of #1262 updated if its text names only four types; `CHANGELOG.md` entry appended under `[Unreleased]`.
