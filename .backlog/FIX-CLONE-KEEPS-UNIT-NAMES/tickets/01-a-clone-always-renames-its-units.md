# 01 — A clone always renames its units

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafDcsSpawner.lua`, `test/lua/test_veafDcsSpawner.lua`

## What was wrong

`VeafGroupSpawn:_spawn` renamed a clone's units in two cases only:

```lua
if self.renameUnits then
  ...
elseif renamed then          -- true ONLY if the GROUP name was already taken
```

`renamed` is the answer to "did I have to invent a group name?", not to "is this a new identity?".
A caller that allocates its own unique group name makes `isNameTaken` answer no, so its units kept
the template's names.

## What was done

The condition is `verb == "clone"`. A clone creates a new identity by definition, so it renames its
units whatever the caller did about the group name.

Both naming shapes are kept, and they mean different things:

| Shape | Asked for by | Reader |
|---|---|---|
| `<group> #<n>` | `renamingUnitsSequentially()` (`veafCombatZone`) | a mission maker reading a zone's units |
| `<group>-<n>` | every clone, by default | the Mission Editor's own shape; `Arco #2 #1` reads as nothing |

The unit names are unique because the group name is. That is now stated in the code, because it is
what ticket 02 had to repair on the caller side.

## Definition of done

- [x] A clone renames its units whether or not its group had to be renamed
- [x] `renameUnits` keeps its own meaning and its own shape
- [x] A respawn and a teleport still keep their unit names
- [x] Tests red before the change, green after
