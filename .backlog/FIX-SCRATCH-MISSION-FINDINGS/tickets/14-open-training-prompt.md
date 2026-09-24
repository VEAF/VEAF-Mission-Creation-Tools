# 14 — A reusable prompt to build an Open Training mission on any map

Status: 🔄 in review
Type: doc
Files: `.prompts/new-open-training-mission.fr.md` and `.en.md` (new), `doc/mission-maker/AI_ASSISTANT_INSTALL*.md`

## Why

David, after the GermanyCW-v6 rebuild: a prompt that lets a new session — another PC, another Claude
user — build a VEAF Open Training on any map, saying how bases are chosen and how many combat zones,
QRA and CAP to make. Written and refined with him on 2026-09-24, then asked for in a `prompts` folder
of VMCT; `.prompts/` already holds the release-notes prompt, so it goes there rather than into a
second folder.

## What it is

The design rules, not an example to copy (David: the model would copy examples blindly): scaled on
the measured size of the front; blue and red bases, a few red ones with slots and blue QRA / CAP in
front of them; support, escorts, short + medium range on every slotted base plus a few long-range
batteries and EWRs behind the lines; three families of three nested training levels (helicopters,
attack, SEAD/DEAD) graded with `defense N`; at least six real zones more than training ones; QRA
covering some places, not all; security on by default with a `LOCAL_TEST` profile; French unless
told otherwise; a « Retours pour VMCT » block for every tool gap met.

It names only what this lot ships (`includes:`, `describe_known_limitations`, `set_mission_date`,
`set_bullseye`, `set_briefing`, the `edit_route` flight tasks, `dynamic_spawn`, `loadout_from`) and
lists no tool trap: those live in `describe_known_limitations`.

## Done when

- David has reviewed the text
- An English version, the same rules (the mission itself stays French by default)
- The mission-maker doc points to both (FR and EN)
