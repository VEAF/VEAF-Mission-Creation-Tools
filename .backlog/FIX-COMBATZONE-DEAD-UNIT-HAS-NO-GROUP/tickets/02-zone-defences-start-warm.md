# 02 — spawned ground vehicles start with their engines running

Status: ⬜ ready — David's ruling, 2026-09-27. Not investigated yet.
Type: fix

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

- [ ] A failing test first: **any** spawned ground group comes out with its engines running, not
      only one spawned into a combat zone
- [ ] Verified in game: the vehicles of a freshly activated zone are acquirable on a TGP
- [ ] The choice is documented where a mission maker will meet it, and says what to write to get the
      other behaviour
- [ ] `poetry run test-lua` green, `stylua --check` and `luacheck` clean
- [ ] `CHANGELOG.md` entry under `[Unreleased]`
