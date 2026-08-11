# Lot FIX-COMMUNITY-SOUNDS-PRUNED — the editor deletes the CSAR and beacon sounds, silently

Status: ✅ done — 2026-08-10

**Goal**: a mission built by veaf-tools, opened in the DCS Mission Editor and saved, comes back with
**five files removed**. Measured by diffing the two archives, not suspected:

```
l10n/DEFAULT/CSAR.ogg
l10n/DEFAULT/beacon.ogg
l10n/DEFAULT/beaconsilent.ogg
l10n/DEFAULT/csar-beacon.ogg
l10n/DEFAULT/veafDynamicConfig.lua
```

None of them appears in `mapResource`. The editor keeps what its own resource table declares and prunes
the rest — reasonable behaviour on its part, since it cannot know that CTLD and CSAR ask for these **by
filename at runtime**, from a script it never reads.

So a mission maker who opens their mission to nudge one group loses the CSAR and beacon audio. Nothing
is said, at build time or after.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Re-create the preload trigger for orphan sounds | ✅ |
| 02 | Pick the country from the top of the DCS table | ✅ |

## The gap was deliberate, and left open on purpose

`BUILD-COMMUNITY-SOUNDS-001` stated its own scope — *"files-only: no `mapResource` entry, no
`out_sound` trigger"* — and `mission_builder_worker.py` recorded the intended sequel **in a comment**,
where nobody was going to trip over it. The build already knew how to *remove* the legacy preload
trigger when CTLD and CSAR are both off; it never learned to *create* it. So v5 missions that carried
the trigger kept working, and every mission built fresh since was one editor save away from losing its
sounds.

## The recipe was in the v5 missions all along

```lua
a_out_sound_c(7, getValueResourceByKey("ResKey_Action_7337"), 0);
```

A mission-start action playing each sound to **country id 7**, which appears in none of that mission's
coalitions — no unit, so nobody ever hears it, while the resource becomes something the editor's table
declares and therefore keeps. The trick is old and known; the build had simply stopped doing it.

## The ticket's own scope was wrong, and was corrected mid-flight

Written as *"when CTLD or CSAR is enabled"*, it **did not fix the reported bug**: the measured sounds
came from the mission's own folder with both modules **disabled**. The rule is about orphan sounds, not
about CTLD.

And the country is taken from the **top** of the DCS table rather than the bottom: `min` would have
handed out id 3 — Turkey — on a Syria map.
