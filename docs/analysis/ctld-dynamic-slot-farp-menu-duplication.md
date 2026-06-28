# CTLD F10 menu duplicated on a dynamic-slot helicopter spawned on a runtime FARP

**Audience:** the developer rewriting CTLD (Fulgas). This documents a reproducible
defect in CTLD `1.5.2` (the VEAF-vendored copy) so the rewrite can verify it is gone.

**TL;DR:** taking a **dynamic slot** on a **runtime-spawned FARP** makes
`ctld.getUnitsInRepackRadius` call `:getGroup()` on a `nil` unit and **error out**.
The error happens *inside* `ctld.addTransportF10MenuOptions`, **after** the F10 menu
has been added but **before** the `ctld.addedTo[groupId] = true` dedup flag is set.
The next birth event therefore re-enters `addTransportF10MenuOptions` and **builds the
whole CTLD menu a second time** → duplicated menu, and the entries do nothing because
the build aborted mid-way.

---

## 1. Symptom (reported by Tripack)

- Mission with CTLD, helicopters available as **dynamic slots**.
- A **FARP is spawned at runtime** (VEAF spawn), next to a normal (editor-placed) slot.
- Taking the **normal** slot → CTLD menu OK (single, working).
- Taking a **dynamic slot on the FARP** → the **CTLD radio menu is duplicated**: every
  entry appears twice; only one copy is "active" and clicking any option does nothing.

Screenshot (radio menu path `Principal > Autre > CTLD`):

```
F1. Check cargo
F2. Troop transport...
F3. Crates Vehicle / FOB / Drone...
F4. CTLD commands...
F5. Check cargo            <- duplicate
F6. Troop transport...     <- duplicate
F7. Crates Vehicle / FOB / Drone...
F8. CTLD commands...
```

Important: a dynamic slot on a **base airfield** does **not** reproduce it — only a
dynamic slot on a **runtime-spawned FARP** does (see §4).

---

## 2. Environment

- CTLD `1.5.2` (VEAF-vendored fork; `ctld.dontInitialize = true`, VEAF re-initializes it).
- MIST `4.5.128-DYNSLOTS-02-VEAF` (the dynamic-slots-aware MIST variant).
- DCS dynamic slots; FARP created at runtime (not present in the `.miz`).

---

## 3. Root cause

### 3.1 The crash

`ctld.getUnitsInRepackRadius` dereferences the result of `Unit.getByName` without a
nil-check:

```lua
function ctld.getUnitsInRepackRadius(_PlayerTransportUnitName, _radius)
    ...
    local unitsNamesList = ctld.getNearbyUnits(unit:getPoint(), _radius, unit:getCoalition())
    local repackableUnits = {}
    for i = 1, #unitsNamesList do
        local unitObject     = Unit.getByName(unitsNamesList[i])   -- can be nil
        local repackableUnit = ctld.isRepackableUnit(unitsNamesList[i])
        if repackableUnit then
            repackableUnit["repackableUnitGroupID"] = unitObject:getGroup():getID()  -- CRASH: unitObject is nil
            table.insert(repackableUnits, mist.utils.deepCopy(repackableUnit))
        end
    end
    return repackableUnits
end
```

For a dynamic slot on a runtime FARP, `getNearbyUnits` returns a unit **name** for which
`Unit.getByName(name)` returns **nil** (a transient/stale entry in `mist.DBs.unitsByName`
that has no live DCS unit). `isRepackableUnit(name)` still returns a truthy table (it
matches by type name / DB), so the guarded branch runs and `unitObject:getGroup()` throws:

```
[string "CTLD.lua"]:<getUnitsInRepackRadius>: attempt to call method 'getGroup' (a nil value)
```

`ctld.isRepackableUnit` has the same latent nil-deref:

```lua
function ctld.isRepackableUnit(_unitName)
    local unitObject = Unit.getByName(_unitName)
    local unitType   = unitObject:getTypeName()   -- nil-deref risk with the same root cause
    ...
```

### 3.2 Why the crash *duplicates the menu*

The call chain is:

```
processHumanPlayer()                      -- on S_EVENT_BIRTH / S_EVENT_PLAYER_ENTER_UNIT
  └─ ctld.addTransportF10MenuOptions(unitName)
       ├─ missionCommands.addSubMenuForGroup(...)   -- builds the CTLD menu (Check cargo, Troops, Crates, …)
       ├─ ctld.updateRepackMenu(unitName)           -- line ~6895 ("add repack menu")
       │    └─ ctld.getUnitsInRepackRadius(...)      -- *** ERRORS HERE ***
       └─ ctld.addedTo[tostring(groupId)] = true     -- dedup flag — NEVER REACHED
```

`addTransportF10MenuOptions` only sets its dedup flag (`ctld.addedTo[groupId] = true`) at
the very **end** of the function. Because `updateRepackMenu` → `getUnitsInRepackRadius`
throws *before* that line, the flag is never set even though the menu was already added.

DCS emits **two** events when a player takes a slot (`S_EVENT_PLAYER_ENTER_UNIT` **and**
`S_EVENT_BIRTH`). For dynamic slots both are deferred ~2 s (the unit isn't in
`mist.DBs.humansByName` yet), so `addTransportF10MenuOptions` runs **twice**; with the
dedup flag never set, the second run **re-adds the whole menu** → the duplicate.

`addedTo` is keyed by group id, and both runs see the same id, so the dedup *would* have
worked — the only reason it doesn't is the mid-function crash that skips the flag.

### 3.3 Why dynamic-slot-on-FARP specifically

A dynamic slot on a **base airfield** gives a stable unit whose neighbours all resolve to
live units → `getUnitsInRepackRadius` doesn't hit a nil unit → no crash → dedup flag set →
single menu. A dynamic slot on a **runtime-spawned FARP** leaves a transient name in
`mist.DBs.unitsByName` (FARP statics / dynamic-slot artifacts) that resolves to `nil`,
triggering the crash. This matches the empirical result (airfield = OK, FARP = duplicated).

---

## 4. Runtime evidence

Diagnostic build: a wrapper around `ctld.addTransportF10MenuOptions` logging, at INFO
level, the unit name, the MIST group id (used for dedup), the live DCS group id, and the
`addedTo` state, on enter and exit.

**Dynamic slot on a base airfield (Sukhumi) — no duplication:**

```
[DIAG-CTLD] addTransport ENTER unit=Sukhumi-Babushara_UH-1H_0-1 mistGroupId=1000000 liveGroupId=1000000 addedTo[mist]=nil
[DIAG-CTLD] addTransport EXIT  unit=Sukhumi-Babushara_UH-1H_0-1 mistGroupId=1000000 addedTo[mist]=true
```

One build; group id stable; dedup flag set. ✔

**Dynamic slot on a runtime-spawned FARP — duplication:**

```
[DIAG-CTLD] addTransport ENTER unit=FARP KM9172-27.927_UH-1H_13-1 mistGroupId=1000013 liveGroupId=1000013 addedTo[mist]=nil
ERROR SCRIPTING: Mission script error: [string "CTLD.lua"]:2842: attempt to call method 'getGroup' (a nil value)
stack traceback:
	[C]: in function 'getGroup'
	CTLD.lua:2842: in function 'getUnitsInRepackRadius'
	CTLD.lua:6978: in function 'updateRepackMenu'
	CTLD.lua:6884: in function 'addTransportF10MenuOptions'
	CTLD.lua:9403: in function 'processHumanPlayer'
	CTLD.lua:9426: in function <CTLD.lua:9424>
[DIAG-CTLD] addTransport ENTER unit=FARP KM9172-27.927_UH-1H_13-1 mistGroupId=1000013 liveGroupId=1000013 addedTo[mist]=nil
ERROR SCRIPTING: Mission script error: [string "CTLD.lua"]:2842: attempt to call method 'getGroup' (a nil value)
	(same traceback)
```

Note: **two `ENTER`, no `EXIT`** for either (the function never returns normally), and
`addedTo[mist]` is **still `nil`** on the second enter (same group id `1000013`) — proving
the dedup flag was never set because of the crash, and that the menu is therefore built
twice. (Line numbers are from the injected copy; they map to the functions named above.)

---

## 5. Fix applied in the VEAF-vendored copy

Defensive nil-guards so a stale/transient name (no live unit, or a unit without a group)
is skipped instead of crashing:

```lua
-- ctld.getUnitsInRepackRadius
for i = 1, #unitsNamesList do
    local unitObject     = Unit.getByName(unitsNamesList[i])
    local repackableUnit = ctld.isRepackableUnit(unitsNamesList[i])
    if repackableUnit and unitObject then
        local _group = unitObject:getGroup()
        if _group then
            repackableUnit["repackableUnitGroupID"] = _group:getID()
            table.insert(repackableUnits, mist.utils.deepCopy(repackableUnit))
        end
    end
end
```

```lua
-- ctld.isRepackableUnit
function ctld.isRepackableUnit(_unitName)
    local unitObject = Unit.getByName(_unitName)
    if not unitObject then
        return nil  -- stale/transient name with no live unit (dynamic slots / spawned FARPs)
    end
    local unitType = unitObject:getTypeName()
    ...
```

With the crash gone, `addTransportF10MenuOptions` runs to completion, sets
`ctld.addedTo[groupId] = true`, and the second birth event is correctly deduplicated.

---

## 6. What to verify / harden in the CTLD rewrite

1. **Never dereference `Unit.getByName(...)` without a nil-check.** `getNearbyUnits` /
   `getUnitsInRepackRadius` / `isRepackableUnit` all assume a live unit; with dynamic
   slots and runtime-spawned FARPs, `mist.DBs.unitsByName` (or any nearby-units source)
   can yield a name with no live unit. Same applies to `:getGroup()`/`:getGroup():getID()`.
2. **Set the menu-dedup guard *before* building, or make the build idempotent.** The
   current pattern sets `addedTo[groupId] = true` only at the *end* of a long function;
   *any* error before that line silently leaves the menu added but not flagged, so the
   next birth event duplicates it. Prefer: mark the group as "menu being/already built"
   up-front, and/or remove an existing CTLD menu for the group before rebuilding.
3. **Dynamic slots fire two events** (`S_EVENT_PLAYER_ENTER_UNIT` + `S_EVENT_BIRTH`) and
   the unit is not yet in MIST's human DB, so menu setup is deferred and runs twice. The
   dedup must be robust to that (idempotent, or keyed on a stable identity).
4. **Group id source.** This copy dedups using `ctld.getGroupId` =
   `mist.DBs.unitsById[id].groupId` (the MIST DB), not the live `unit:getGroup():getID()`.
   For the observed case they matched (`1000013`), but a rewrite should prefer the live
   API for dynamic slots, or guarantee the two are consistent.
5. **Regression scenario to test:** spawn a FARP at runtime, take a dynamic-slot
   helicopter on it, and confirm the CTLD F10 menu is built exactly once and all options
   work — and that no `attempt to call method 'getGroup'/'getTypeName' (a nil value)`
   error appears in `dcs.log`.
