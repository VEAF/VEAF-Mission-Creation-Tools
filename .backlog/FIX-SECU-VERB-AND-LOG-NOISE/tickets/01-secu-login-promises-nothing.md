# 01 — a listed pilot's level does not reach the radio menu; `/secu login` promises what it cannot give

Status: ⬜ ready

David, in flight on private1, 2026-09-29: *"the radio menu for activating combat zones is not
unlocked although I am in the server's pilot file. And even after `/secu login` — it answers
'mission authenticated for 10 minutes' — it is still protected."*

## Measured on the running server (2026-09-29)

- `veaf-pilots.txt`: `name="Zip", level=99`. The combat-zone command asks for
  `LEVEL_SENIOR_PILOT` = 10. **His level is not the problem.**
- 19:20:59 `/secu login` → `VEAF-SECURITY|I: [Ninja 1-1 | Zip] is unlocking the mission`, plus
  `WARNING VEAF-SECURITY|W|authenticate: unusable auth duration [], using the default`. The menu
  kept refusing afterwards.
- 19:38:38 `/secu elevate` → `group 1000166 elevated to level 99 for 120 seconds by
  [Ninja 1-1 | Zip]`, and 17 s later a zone activation came through
  `VEAF-COMBATZONE|I|realMethod` — the secured proxy's own path. So the menu itself is sound.

## What the documentation promises

`doc/mission-maker/scripts/veafSecurity.md`, the "l'authentification n'est plus globale" danger box:

> **Pour un pilote listé dans `veaf-pilots.txt`, rien ne change** : son niveau suffit, et il n'a
> jamais eu besoin du mot de passe.

That did not hold. A pilot at level 99 had to elevate by hand to click a command asking for 10.

## The code path, and where it can drop the level

`_proxyMethod` → `veafSecurity.getEffectiveGroupLevel(groupId)` → `getGroupLevel` →
`getPilotLevelForUnit(unitName)` → `veafRemote.getRemoteUserFromUnit(unitName)` →
`veafRemote.remoteUnitsPilots[unitName]`, whose `.level` is the answer.

That table is filled by `veafRemote.registerUserSlot` (`veafRemote.lua:165`), and it contains:

```lua
local remoteUser = veafRemote.remoteUsers[username:lower()]
if not remoteUser then
  remoteUser = { name = username, ucid = ucid }   -- no level
end
...
veafRemote.remoteUnitsPilots[occupiedUnit] = remoteUser
```

So when the pilot is **not already in `remoteUsers`**, the slot is registered with a user object
that has **no `level` at all**, `getPilotLevelForUnit` returns nil, `getGroupLevel` reads 0, and
every secured command is refused — silently, since a refused click logs at `debug`. The fabricated
user is not written back to `remoteUsers` either, so the state does not repair itself on the next
slot change.

`remoteUsers` is filled from the hook's `onPlayerConnect` (`REGISTER_PLAYER`, carrying
`pilot.level` read from `veaf-pilots.txt` by UCID) and, for a pilot above level 0, from the chat
path. **A player already connected when the mission loads or reloads gets no `onPlayerConnect`**,
so the mission's `remoteUsers` starts empty for him while he keeps flying — the scenario to check
first.

This also explains why `elevate` worked where the menu did not: the chat payload carries the level
explicitly (`executeCommandFromRemote("Ninja 1-1 | Zip", "99", ...)`), so that path never needs
`remoteUnitsPilots`.

## Done when

- A pilot listed at level ≥ 10 can use a secured radio command **without any verb**, including
  after a mission reload while he stays connected — the documented promise, held.
- `registerUserSlot` no longer invents a level-less user: either it refuses and says so at `warn`,
  or it asks the hook for the level. Tested both ways.
- `/secu login` either grants what it announces or says plainly that it no longer opens a session,
  and the `unusable auth duration []` warning goes away (the chat payload sends an empty duration).
- `doc/mission-maker/scripts/veafSecurity.md` and `veafServerHook.md` agree with what the code
  does; `/secu login` is listed at level 10 in the hook's table while its effect is now nil.

## To measure before fixing

The server ran at INFO, where `registerUserSlot` and the refusal both log at `debug`. One session
with `VEAF-REMOTE` and `VEAF-SECURITY` at debug settles which of the two cases happened; without
it, the reconstruction above stays a reading of the code.
