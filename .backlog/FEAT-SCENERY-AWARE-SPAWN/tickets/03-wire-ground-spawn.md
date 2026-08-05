# 03 — Wire the helper into the jittering spawn paths

Status: ✅ done
Type: feat
Files: `src/scripts/veaf/veafSpawnGround.lua`, `src/scripts/veaf/veafSpawnCore.lua`, `test/lua/test_veaf.lua`, `test/lua/test_veafSpawnGround.lua`

Depends on: 02

## Where it goes — decided by reading all six sites

Only where a spawn point is **chosen for a group**, never per unit: `veafUnits.placeGroup` lays the
units out around that centre, so moving units individually would break the formation the group
definition describes.

Five sites already do `veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))` — they
jitter **once**, unvalidated. That is exactly what the helper replaces, and it makes them
unambiguously the "somewhere sensible near here" case:

| Site | Function |
|---|---|
| `veafSpawnGround.lua:319` | `spawnInfantryGroup` |
| `veafSpawnGround.lua:372` | `spawnArmoredPlatoon` |
| `veafSpawnGround.lua:411` | `spawnAirDefenseBattery` |
| `veafSpawnGround.lua:463` | `spawnTransportCompany` |
| `veafSpawnCore.lua:636` | `doSpawnGroup` (the generic spawner, reached via `veafSpawn.spawnGroup`) |

**`veafSpawnGround.lua:636` is left alone** — the convoy. Its `spawnSpot` is a departure point, and
`veaf.generateVehiclesRoute(spawnSpot, destination, …)` at `:645` builds the route **from that same
point**: moving the spawn laterally would desync the route origin from where the vehicles actually
are. This is the "exactly here, the mission maker means it" case. No sweep for symmetry.

`veafUnits.checkPositionForUnit` is **not touched** — see the PRD on why the validator and the finder
stay separate.

The redundant second `veaf.placePointOnLand(spawnSpot)` a few lines below each site (e.g.
`veafSpawnGround.lua:378`) is left in place: it is idempotent on an already-lowered point, and
removing it is unrelated cleanup (RULE N°1).

## Failure handling

The helper can now return `nil`, so each site must handle it. The precedent to follow is
`veafSpawnCore.lua:645-651`, which already aborts with a message and returns `nil`:

```lua
if not spawnSpot then
  veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning the group")
  if not silent then
    trigger.action.outText(veaf.t("spawn.no_position_group"), 5)
  end
  return nil
end
```

`silent` is respected at every site — a scripted spawn must not spam a player. The abort replaces the
old behaviour where a bad centre still ran the whole spawn and produced nothing, one dropped unit and
one message at a time.

## Tasks

- [x] Five sites switched from `placePointOnLand(getRandPointInCircle(…))` to `veaf.findSpawnPoint`.
- [x] `nil` handled at each: log, `outText` unless `silent`, return `nil`.
- [x] Convoy site untouched, with a comment stating why the route origin pins it.
- [x] Tests: `Disposition` absent + jitter landing on water then land → the group centre is the land
      point, spawn succeeds (this is the case that silently produced nothing before).
- [x] Tests: `Disposition` present and proposing an offset point → the centre moves and `placeGroup`
      receives it.
- [x] Tests: every candidate on water → spawn returns `nil`, one message emitted, `placeGroup` never
      called.
- [x] Test: `silent = true` on failure → no `outText`.
- [x] Test: `veaf.doNotAvoidScenery = true` with the mock present → tier 1 skipped, singleton never
      called.

## Acceptance criteria

- [x] `poetry run test-lua`: no regression. Per-suite before/after diff is identical everywhere except
      the two suites this lot adds to (`test_veaf` 241 → 266 successes, `test_veafSpawn` 150 → 158).
      **Not** "all green": 34 tests fail locally under Lua 5.4 — `unpack`, and `%d` on a float — because
      the runner falls back to the system `lua` when `lua5.1` is absent. CI installs 5.1, where those
      pass. `test_veafUnits` is additionally **flaky** for the same reason (5 green / 3 red over 8 runs
      at constant code, seeded by `math.randomseed(os.time())`); pre-existing, verified by stashing.
- [x] `luacheck` (0 warnings / 0 errors, 42 files) + `stylua --check` clean; `docs-check` no defect.
- [x] No existing assertion was changed — the two suites only gained tests.
- [ ] Lua coverage floor **deliberately not bumped**: measured 70.43% against a gate of 70.00%, so the
      gap is 0.43 points, already inside the ~2-point tolerance the ratchet policy allows. Bumping to
      70.4 would leave 0.03 points of headroom on a suite with a known flaky test, trading a satisfied
      policy for a red CI. New code is well covered (`veaf.lua` 62.13% → 63.03%, 68 of ~69 new lines).
- [ ] Verified in game on a marker spawn over a village — belongs to ticket 01, deferred by David.
