# FIX-COMMUNITY-SOUNDS-PRUNED — the editor deletes the CSAR and beacon sounds, silently

Status: ⬜ ready

## Measured, not suspected

Found on 2026-08-09 while testing something else: a mission built by veaf-tools was opened in the
DCS Mission Editor and saved. Comparing the two archives, the editor had **removed five files**:

```
l10n/DEFAULT/CSAR.ogg
l10n/DEFAULT/beacon.ogg
l10n/DEFAULT/beaconsilent.ogg
l10n/DEFAULT/csar-beacon.ogg
l10n/DEFAULT/veafDynamicConfig.lua
```

None of them appears in `mapResource`. The editor keeps what its own resource table declares and
prunes the rest, which is reasonable behaviour on its part — it cannot know that CTLD and CSAR ask
for these by **filename at runtime** (`outSound`), from a script it never reads.

So a mission maker who opens their mission in the editor to nudge one group loses the CSAR and
beacon audio. Nothing is said, at build time or after.

## The gap is deliberate, and was left open on purpose

`BUILD-COMMUNITY-SOUNDS-001` (archived, ✅) states its own scope:

> Files-only — **no `mapResource` entry, no `out_sound` trigger**.

And `mission_builder_worker.py:1250` records the intended sequel in a comment, where nobody was
going to trip over it:

> (Re-creating it when a module is enabled is the BUILD-COMMUNITY-SOUNDS lot.)

The build knows how to **remove** the legacy preload trigger when CTLD and CSAR are both off
(`TRIGGERS-VERIFY-004`, `_find_community_sound_resource_keys`). It never learned to **create** it.
So v5 missions that carried the trigger kept working, and every mission built fresh since has been
one editor save away from losing its sounds.

## The recipe already exists, in the missions themselves

A v5 VEAF mission carries exactly what is needed:

```lua
a_out_sound_c(7, getValueResourceByKey("ResKey_Action_7337"), 0);
a_out_sound_c(7, getValueResourceByKey("ResKey_Action_7338"), 0);
```

A mission-start action playing each sound **to country id 7**, which appears in none of that
mission's coalitions — no unit, so nobody ever hears it, while the resource becomes something the
editor's table declares and therefore keeps. The trick is old and known; the build simply stopped
emitting it.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Register the sounds so the editor keeps them](tickets/01-register-community-sounds.md) | ⬜ |
| 02 | [Stop embedding `veafDynamicConfig.lua` in the archive, or register it](tickets/02-orphan-dynamic-config.md) | ⬜ |

## Why it matters

The failure is invisible on both sides. The build reports success. The editor reports success. The
mission runs, and a CSAR beacon that used to beep is simply silent — which reads as a CTLD bug, not
as "your editor deleted the file".
