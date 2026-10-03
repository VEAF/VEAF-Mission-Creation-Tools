# 01 — a listed pilot's level does not reach the radio menu; `/secu login` promises what it cannot give

Status: 🧑 waiting-human — fixed and tested; the in-game check needs the redeployed hook

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

## Resolution

Reading the code further found the **second half**, which is why `/secu login` repaired nothing even
though the chat path does register a listed pilot: `veafServerHook.parse` injects `REGISTER_PLAYER`
for any pilot above level 0, but `veafRemote.registerUser` stored a **new** table, and
`remoteUnitsPilots[unit]` kept pointing at the level-less one `registerUserSlot` had made. Both halves
are fixed, each tested on its own:

- `registerUser` updates the user it already holds, so every table that points to that user sees the level.
- `registerUserSlot` keeps the user it creates in `remoteUsers`, takes a 4th argument, the level, and
  warns (`took [...] with no known level`) when a player takes a unit with none known anywhere.
- The hook sends that level with every slot change (the administrator's through `ADMIN_FAKE_UCID`, as
  on the chat path; an unlisted player's as `-1`). A mission meeting an **older hook** still gets the
  repair from the first chat command, and the warning says what happened meanwhile.
- `getMarkerSecurityLevel` reads a user with no level as unknown (-1) instead of comparing nil.
- `/secu login` and `/secu logout` (chat and `_auth` marker) no longer touch the dead global flag:
  they answer, in the pilot's unit only, that there is no global login any more and point to
  `/secu elevate`. So the `unusable auth duration []` warning is gone with the call that raised it.
- Docs: `veafSecurity.md` (+ EN) no longer teaches login/logout as verbs that act, and says what the
  `+` means; `veafServerHook.md` (+ EN) drops `/secu login|logout` from the level-10 row and says why
  the hook must be redeployed.

**Not measured**: which of the two ways in actually happened on private1 — the debug session the
ticket asked for was not run. The fix covers both, so the question no longer decides anything.

**Deployed 2026-10-01.** `VEAF-Server-hook.lua` v2.7.1 (this lot's `cf9958e9`) is installed on all
six instances — `foothold1/2`, `private1/2`, `public1/2` — each verified after the copy at 33 814 o
with `onGameEvent` and the four-argument `registerUserSlot`; the previous ones (31 826 o, dated
2026-08-10) are kept server-side in `Saved Games\_hook-backup-20261001-091118\`. All six restarted
at 09:14–09:15 local, so the new hook is the one loaded.

Two things that cost time and are worth recording:

- **The hook does not ship in a release.** `published/` carries the mission scripts only
  (`veaf-scripts.lua` and the community ones), no `Scripts/Hooks/`, so `veaf-tools-updater` cannot
  bring a hook fix to a server: it has to be copied by hand from `src/scripts/Hooks/`. Everything
  else in this lot reached the servers through 6.26.0; this half did not, and nothing said so.
- The directory is `src/scripts/Hooks/`, with a capital H. Git is case-sensitive where Windows is not, so a
  `git ls-files src/scripts/hooks/` comes back empty and the file looks untracked.

**Left**: the in-game check — a listed pilot, still connected across a mission reload, clicks a `+`
command without any verb.

`veafSecurity.authenticate`, `logout`, `isAuthenticated`, the `authenticated` flag, `authDuration` and
their four i18n strings had no caller left; removed in this lot on David's go, so nobody wires the
promise back.

The review also asked whether `remoteUsers`, keyed by **name** where the hook keys pilots by UCID,
lets a same-name player overwrite a listed pilot's level. Measured on the six servers' logs
(2026-09-23 → 09-30): 93 connections, 20 names, **no name ever seen with two UCIDs**. Not pursued.
