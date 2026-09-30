# 02 — spawned ground vehicles start with their engines running

Status: 🧑 waiting-human — built 2026-09-29; only the in-game check is left.
Type: fix

## 2026-09-29 — what was found and built

1. **The lever is `coldAtStart`, per unit.** DCS 2.8.4.39731 (stable, 2023-05-05): *"ME Setting
   'COLD AT START' now working as intended for FLIR rendering. Not selecting this option will allow
   units to have infrared signatures at mission start rather than first needing to heat up."*
2. **The editor already writes it `false`**: all 185 ground units of GermanyCW-v6's `mission` carry
   `coldAtStart = false`, none `true`. A table built by a script — `veafSpawnCore` for a `#command`
   group, a convoy, a marker spawn — had **no key at all**, and what DCS does with a missing key is
   **not established**.
3. **Built**: `veafDcsSpawner.addGroup`, the single path every group goes through, now writes
   `coldAtStart = false` on a ground unit that has none, next to the `playerCanDrive` default it
   already set. A unit the mission maker ticked cold keeps `true`: the mission record
   (`veafMissionDb`) did not carry the key, so the review of this lot caught a respawn turning such
   a unit warm; the record now projects it. Aircraft and ships are untouched.
4. **What this cannot fix — and it may be what was seen.** The Wahner Heide `-cible-N` targets are
   now **statics** (the 2026-09-28 log), and a static has no engine. They stay cold on a pod whatever
   the scripts do; only turning them into groups in the mission would change that. And if DCS already
   read a missing key as warm, the vehicles David found cold went cold by **standing still**, which
   no mission option is known to prevent — the in-game check tells which.

## What was asked

Flying `combatZone_WahnerHeide_Medium` on 2026-09-26, David found the zone's vehicles **cold**, and
so very hard to acquire on the A-10's TGP. Asked whether that was intended, his answer was plain:
**he would rather they were warm.**

That is the whole requirement. A cold vehicle is realistic, but a combat zone exists to be found and
attacked, and a target nobody can acquire is not a target — it is a search exercise nobody asked for.

## What has to be found out

Nothing here is established. In order:

1. **Are they cold by accident or by default?** Whether anything in the spawn path touches the
   engine state at all, or whether DCS simply starts ground units cold and nobody ever asked
   otherwise.
2. **What the lever is.** A per-unit property written at spawn, a group-level setting, or an AI
   task — and whether it survives a respawn, since combat zones recycle their content.
Point 3 is already settled: **it applies to every spawn**, not only to combat zones. David,
2026-09-27. So this is a change to the spawn path itself rather than something a zone asks for, and
it will reach convoys and lone vehicles too.

## Definition of done

- [x] A failing test first: **any** spawned ground group comes out with its engines running, not
      only one spawned into a combat zone (`test_veafDcsSpawner.lua`, `test_a_ground_unit_starts_warm`)
- [ ] Verified in game: the vehicles of a freshly activated zone are acquirable on a TGP
- [x] The choice is documented where a mission maker will meet it, and says what to write to get the
      other behaviour (`veafSpawn` `#warm-start`, combat zone `#static-targets`)
- [x] `poetry run test-lua` green, `stylua --check` clean (`luacheck` by the CI)
- [x] `CHANGELOG.md` entry under `[Unreleased]`
