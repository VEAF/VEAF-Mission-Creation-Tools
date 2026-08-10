# 01 — Register the sounds so the editor keeps them

Status: ✅ done — 2026-08-10
Type: fix
Files: `src/python/veaf-tools/mission_builder/mission_builder_worker.py`, `test/python/`

## Tasks

- [ ] When CTLD or CSAR is enabled, emit a mission-start action playing **each** injected sound to
      a country **absent from the mission's coalitions**, and add the matching `mapResource` entry.
      That pairing is the whole fix: the trigger alone does nothing, the `mapResource` entry alone
      is what the editor reads.
- [ ] Pick the unused country by **checking the mission**, not by hardcoding 7. A hardcoded id is
      correct until the day someone uses that country and starts hearing beacons at mission start.
- [ ] Reuse `_find_community_sound_resource_keys` — the removal side already knows how to find
      these keys, so creation and removal should agree by construction rather than by coincidence.
- [ ] Symmetry test: build with CTLD on, save through the editor, assert the sounds survive. The
      unit test that merely asserts a trigger exists would have passed all along.

## Watch out

`radiobeep.ogg` was added later (BUILD-COMMUNITY-SOUNDS-002, #505) and is auto-injected for CTLD.
It needs the same treatment — the mapping is the source of truth, not the three names in the
original lot.

## Done

A *Declare mission sounds* trigger (the 7th VEAF trigger, emitted only when there is something to
declare) plus one `mapResource` entry per sound. Verified on a real build: the four `.ogg` the demo
mission carries are declared, both emitted forms agree, and the chosen country is absent from every
coalition.

### The scope was wrong and the first implementation proved it

Ticket 01 said *"when CTLD or CSAR is enabled"*. Written that way, it **did not fix the reported
bug**: the sounds that were measured came from the mission's own `src/mission/l10n/DEFAULT/` with
`CTLD: false` and `CSAR: false` in its `mission.yaml`, so the tool-injected set was empty and no
trigger was emitted. Caught by building the very mission the lot was filed from, not by a test.

The rule is now about **orphans**: every `.ogg` bound for `l10n/DEFAULT/` that no `mapResource`
entry already names, whatever put it there. A sound with its own trigger — a briefing clip — is
left alone.

### The country choice was wrong too, in the same direction

`min` over the free ids looked harmless and was not: 0 Russia, 1 Ukraine, 2 USA, **3 Turkey**. On a
Syria map that hands beacons to Turkey the day someone adds it. It picks from the **top** now
(92 New Zealand and down) — and the pre-existing test fixture in `test_community_sound_trigger.py`
had been using 89 (Peru) all along, which says the same thing.

### Interaction with TRIGGERS-VERIFY-004, stated rather than assumed

That ticket removes the **legacy v5** sound trigger when both modules are off. This one emits a
**generated** declaration. Net effect: one clean generated trigger instead of a stale hand-made
one, which is what 004 wanted. The one behaviour change worth flagging is that with both modules
off the sounds are now still declared — because the alternative is shipping files we know the
editor will delete.
