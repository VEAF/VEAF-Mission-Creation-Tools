# 01 — a zone owns the groups its own elements spawn

Status: ⬜ ready — diagnosed from a run's `dcs.log` on 2026-09-27, cause established, fix not written.
Type: fix

## The defect

Membership in a combat zone is decided by a **name prefix**: a group belongs to the zone whose name
its own name starts with. That keeps foreign groups out, which is what the convention is for
([`DOC-COMBATZONE-PREFIX-RULE`](../../DOC-COMBATZONE-PREFIX-RULE/PRD.md)).

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

Worth deciding alongside: whether a spawned group should also *be named* after its zone. That would
fix ownership as a side effect, and it would also change every generated name a player sees in the
F10 map and in kill messages — a mission-maker-visible change rather than a bug fix.

## Not established

**Which zones were active besides Medium.** The two spawn commands found in the log are tagged
`#wahnerheide_hard-1` and `#wahnerheide_hard-2`, so the groups that died may belong to **Hard**.
That would mean the flight was also shooting a neighbouring zone's targets — the three Wahner Heide
zones overlap, and the log shows them excluding each other's groups by name. It changes which zone
should have counted the kills; it does not change the defect, since neither zone can recognise a
generated name. Pin it before writing the fix.

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
