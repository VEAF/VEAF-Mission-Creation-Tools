# FIX-CLONE-KEEPS-ITS-SOURCE-NAME — every clone of a group is called the same thing

Status: ✅ done — 2026-08-31

Origin: found 2026-08-30 while checking a stale comment in `veafMissionDb`, during `DROP-MIST`
ticket 08. Not reported from a mission — measured directly, see below.

## What happens

`MiST.dynAdd` invented a fresh name for a **clone whose name was already taken**:

```lua
if newGroup.clone and mist.DBs.groupsByName[newGroup.name] or not newGroup.name then
  newGroup.name = tostring(newCountry .. tostring(typeName) .. mistDynAddIndex[typeName])
```

`veafDcsSpawner.addGroup` only invents one when **no name was supplied at all**:

```lua
group.name = group.groupName or group.name
if not group.name then
  group.name = string.format("%s %s %s", countryName, string.lower(category), group.groupId)
end
```

There is no collision check. Cloning a group that still exists produces a second group with the same
name — and a third, and a fourth.

## Measured, not assumed

Three clones of an editor group `Arco`, through the same chain `veafQraCore` and `veafAirWaves` use,
with no `:named()`:

```
#1  group=Arco  units=[Arco-1]
#2  group=Arco  units=[Arco-1]
#3  group=Arco  units=[Arco-1]
```

Three calls to `coalition.addGroup`, one name. Unit names collide too.

## Who is exposed

Both callers of `:clone()` in the repository, and neither passes a name:

| Caller | Line |
|---|---|
| `veafAirWaves.lua` | 1048 |
| `veafQraCore.lua` | 1028 |

Both then do `table.insert(self.spawnedGroupsNames, newGroup.name)` and later look their groups up by
that name. `Group.getByName` can only ever answer one of the homonyms, so a QRA that has respawned
twice is tracking an ambiguous handle: whether it watches the group it just created is not something
the code decides.

## The fix already exists and is not plugged in

`veafMissionDb` has had the answer since ticket 04:

- `isNameTaken(name)` — true for an editor name **or** one VEAF has taken. It answers `true` for
  `Arco` right now, during the very spawn that collides.
- `takeSpawnedName(name)` / `releaseSpawnedName(name)` — the registry either side of it.

`takeSpawnedName` and `isNameTaken` have **no caller anywhere outside their own module**. Ticket 04's
comment says they are there because *"ticket 07 is written against it"*; ticket 07 ported `dynAdd`
and the teleport path without ever asking them. `releaseSpawnedName` is called (by
`veafSpawnAircraft`, for an AFAC callsign), so the registry is released but never taken — which is
also why nothing failed loudly.

## Scope

- `addGroup` asks `isNameTaken` before accepting a supplied name **on a clone**, and derives a free
  one when it is taken. A respawn or a teleport keeps its name: those reuse an identity rather than
  creating one, which is the same distinction MiST drew with its `clone` flag.
- The chosen name is registered with `takeSpawnedName`, so the second clone does not collide with the
  first — the registry has to be *taken*, not only released, or the check only ever sees the editor.
- Unit names inside a renamed group follow, as they did in MiST (`newGroup.name .. " unit" .. index`).
- `:named()` still wins: an explicit name is the caller's business, and this must not silently
  rename what a mission maker asked for. But a **supplied name that is taken** on a clone is the
  ambiguous case — decide it and say so in the log, rather than creating the homonym quietly.

## What was done

`_spawn` asks `isNameTaken` before accepting a name **on a clone**, derives a free one when it is
taken, and registers it with `takeSpawnedName` -- which had no caller at all until now, so the check
only ever saw the Mission Editor's names and two clones could still collide with each other.

The derived name keeps the lineage readable: a clone of `Arco` becomes `Arco #2`, its units
`Arco #2-1`. MiST answered `country .. type .. index` here, so a clone of `Arco` came back as
`USAKC-1353` -- unique, and useless on the F10 map or in a log, which is where these names are read.

`freeNameFrom` walks suffixes up to a ceiling of 100 and then falls back to an allocated id, unique
by construction. The ceiling is not a real limit (reaching it needs 98 live groups from one name):
it exists so a defect in `isNameTaken` cannot turn this into an endless loop at spawn time.

A respawn and a teleport keep their name -- they reuse an identity rather than creating one, the
same line MiST drew with its `clone` flag.

## Definition of done

- [x] A test spawns the same group three times through `:clone()` and asserts **three distinct
      names**, at the `coalition.addGroup` boundary — the probe above, turned into a test
- [x] A test asserts a `respawn` and a `teleport` **keep** their name, so the fix does not leak into
      the paths that reuse an identity
- [x] `takeSpawnedName` has a caller; `isNameTaken` has a caller. Asserted by a test that drives
      `:clone()` and then reads the registry — not by calling the registry directly, which is what
      let this sit unplugged
- [x] Unit names within a renamed clone are unique too
- [x] `veafAirWaves` and `veafQraCore` track a name that designates exactly one group; their existing
      tests still pass
- [x] Lua suite green, `stylua` and `luacheck` clean, `CHANGELOG.md` entry

## Note for whoever picks this up

The interesting question is not the rename — it is why a registry written for this sat unused through
an entire ticket. Both were green the whole time: the registry had tests, the spawner had tests, and
nothing tested that one called the other.
