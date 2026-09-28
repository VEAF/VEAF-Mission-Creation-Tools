# 01 — a zone owns the groups its own elements spawn

Status: 🚫 wontfix — **no defect**. The diagnosis below is refuted by the code, and the sortie's own
log (found 2026-09-28) shows the zone behaving correctly: the last target was still alive when the
flight left. See the next two sections.
Type: fix

## 2026-09-28 — the diagnosis does not survive the code

Read before touching anything, and it contradicts both premises below.

1. **A generated name proves nothing about ownership.** `veaf.HideNamesFromSpawnedGroups` is `true`
   by default (`veaf.lua:42`) and GermanyCW sets it again (`veaf-config.lua:11`), so
   `veaf.getNameForSpawnedGroup` drops the zone name from **every** group a zone respawns —
   editor content included (`veafCombatZone.lua:1729`). `-aaa`'s ZSU-23-4 comes back as
   `[r]-73rd Steel Platoon#…`. "Not one `combatZone_WahnerHeide_*` unit died" is simply what the
   default naming looks like.
2. **The zone already owns what it spawns, whatever the name.** Respawned editor groups go through
   `self:addSpawnedGroup(newGroup.name)` (`:1764`); `#command` groups through the hook registered at
   `:1800` and fired by `veaf.collectSpawnedGroup` (`veafSpawnCore.lua:469`) — #66, covered by
   `test_veafCombatZone.lua:1350`. Both `completionCheck` and `getInformation` iterate
   `getSpawnedGroups()`, never a name prefix. The prefix rule only filters editor content at
   `initialize()`.
3. **Medium holds fifteen vehicles, not eight.** `veaf-config.lua:303` adds Easy's elements to
   Medium: seven one-vehicle `-cible-N` groups (T-72B and the like) plus `-blindes` (5) and `-aaa`
   (3). Fifteen — the number David destroyed.

## 2026-09-28 — the sortie's log: every target died, the last one after the flight left

The log the 2026-09-27 analysis read was not deleted: it is the live `dcs.log` of the `private1`
instance on `dcs.veaf.org` (1 266 `no group found` lines, the 1 264 quoted above plus two later
ones). Read over SFTP, it settles what is left.

- **One activation of Medium, nothing else.** Exactly nine generated groups exist, numbered
  **#25670 to #25678** in a row — seven one-vehicle `-cible-N`, `-blindes` (5), `-aaa` (3). A second
  activation, of Medium or of Hard, would have made eighteen or more. The two `#wahnerheide_hard-*`
  lines the lead above relied on are CTLD registering editor units at mission start
  (`CTLDVehicleSpawner: INIT-D registered MM vehicle`), not commands executing.
- **All fifteen vehicles died, and all fifteen are Medium's.**

  | group | units | deaths |
  |---|---|---|
  | `[r]-India Division#25673` (`-blindes`) | 5 | 19:37:19 → 19:52:35 |
  | `[r]-73rd Steel Platoon#25675` (`-aaa`, the ZSU-23-4) | 3 | 19:41:39 → 19:41:40 |
  | six single-vehicle `-cible-N` | 6 | 19:38:19 → 19:48:45 |
  | `[r]-Chimera Company#25676` (a `-cible-N`) | 1 | **20:21:56** |

- **The flight had gone before the last one died.** Both A-10Cs (`Ramstein_A-10C II_46-1`,
  `_48-1`) landed at 19:59:24 and 19:59:41 and left their slots at 20:02:00 and 20:04:00; players 3
  and 2 disconnected at 20:04:38 and 20:07:03. At that moment Chimera Company was still standing,
  so the zone was right not to complete. Its watchdog checks every 60 s, so it should have completed
  by 20:23 — **not confirmed**, that path logs below `info`.
- **No script error** anywhere in the log, so the watchdog was never killed by a raise (the
  scheduler logs `error in scheduled function` at error level, and there is none).

What remains is presentation, not ownership: the info panel lists what is **left** (one vehicle),
which reads like a low tally when a player expects a kill count. And the one target nobody found is
a single cold vehicle, which is ticket 02.

## The defect

Membership in a combat zone is decided by a **name prefix**: a group belongs to the zone whose name
its own name starts with. That keeps foreign groups out, which is what the convention is for
([`DOC-COMBATZONE-PREFIX-RULE`](../../archive/DOC-COMBATZONE-PREFIX-RULE.md)).

But a zone element can *create* a group, through `#command="_spawn armorgroup, defense 3"` and its
`samgroup` twin — and the spawn gives the new group a **generated name**. `[r]-73rd Steel
Platoon#25675`, `[r]-India Division#25673`, `[r]-Bravo Fighters#25678`. None of those begins with
the zone's name, so **the zone disowns the groups its own elements brought into being.**

## Measured, from the 2026-09-26 evening sortie on GermanyCW

David flew `combatZone_WahnerHeide_Medium` as a two-ship of A-10s and destroyed "about fifteen"
vehicles.

- The zone owns **eight** vehicles: the editor groups `-aaa` (3) and `-blindes` (5).
- **Fifteen named units died**, and **not one is a `combatZone_WahnerHeide_*` unit**. Every named
  death in the whole run carries a generated name. Fifteen — exactly the number reported.
- Skynet logs one of them as a real site: `RADAR RANGE ZERO [[r]-73rd Steel Platoon#25675]:
  radars=1 live=1 launchers=1 … ZSU-23-4 Shilka`. These are the zone's defences, spawned by its own
  elements.

Two symptoms follow from that one cause, and both were reported:

| reported | why |
|---|---|
| the kill count sat far below what was destroyed | the zone counts only what it recognises, and it recognises none of them |
| the zone never deactivated although everything was dead | it goes on waiting for `-aaa` and `-blindes`, which nobody attacked |

## What the fix has to do

**Record the originating zone when the group is created**, rather than deducing ownership from the
name afterwards. The name prefix stays as it is for editor content — it works, and changing it would
break every mission — but a group a zone spawned must not have to prove its parentage by its name.

**Renaming the spawned groups is ruled out.** It would fix ownership as a side effect, and David
settled it on 2026-09-27: the generated names are deliberate — `[r]-73rd Steel Platoon`,
`[r]-India Division` — and they are what a player reads in the F10 map and in kill messages. They
stay. So ownership has to be recorded, not spelled out in a name.

## Not established

**Which zones were active besides Medium.** The two spawn commands found in the log are tagged
`#wahnerheide_hard-1` and `#wahnerheide_hard-2`, so the groups that died may belong to **Hard**.
That would mean the flight was also shooting a neighbouring zone's targets — the three Wahner Heide
zones overlap, and the log shows them excluding each other's groups by name. It changes which zone
should have counted the kills; it does not change the defect, since neither zone can recognise a
generated name. Pin it before writing the fix.

**Do not go looking for it in the 2026-09-26 log — it is not there.** Zone activation logs below
`info` and the server ran at `info`, so that run recorded nothing about which zones were switched
on. The log has since been deleted, having given everything it had. Ask David, or reproduce with
`veaf.ForcedLogLevel = "debug"`.

## Definition of done

- [ ] A failing test first: a zone whose element spawns a group **counts that group** and waits for
      it before completing
- [ ] A group spawned by a zone element is attached to its zone at creation, not by its name
- [ ] Editor content still belongs by prefix, and foreign groups are still excluded — the existing
      exclusion tests stay green
- [ ] Verified in game on `combatZone_WahnerHeide_Medium`: the count matches the kills, and the zone
      deactivates when its defences are destroyed
- [ ] `poetry run test-lua` green, `stylua --check` and `luacheck` clean
- [ ] `CHANGELOG.md` entry under `[Unreleased]`
