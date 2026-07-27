# FIX-MAPRESOURCE-KEY — embedded scripts never loaded (resource key in the wrong table)

Status: ✅ done

## Problem (reported by David, seen in the DCS editor)

Opening a bridge mission from the published `veaf-map-capture-kit-6.11.0.zip`, the trigger
`MISSION START (dcs-bridge loading)` was there but its `DO SCRIPT FILE` action showed an
**empty FILE field** — so `dcs-bridge.lua` never ran and no capture was possible.

## Root cause

`add_startup_script_trigger` (`file_static` mode) allocated the resource key into
`content["mapResource"]`, i.e. a sub-table of the **`mission`** file. DCS resolves
`getValueResourceByKey` against the **separate archive member**
`l10n/DEFAULT/mapResource` (`DcsMission.map_resource_content`). The key therefore went
nowhere: script embedded, key unreachable, failure silent.

The build's own injector was never affected — `mission_builder_worker` registers the key
correctly — which is why the missions David used during the kit dry-run worked: they came
from the build, not from this primitive.

## Second defect found while fixing

A `.miz` with **no** `l10n/DEFAULT/mapResource` member lost the key as well: `write_miz`
only rewrites members that already exist in the source archive. The helper now serialises
and supplies that member itself when absent.

## Why the tests missed it

- The unit test asserted the wrong contract: `assert content["mapResource"][key] == …`,
  i.e. it verified the bug.
- The end-to-end test only checked that the `.lua` was in the archive — never that its key
  resolved.

Both fixed; two regression tests added (key resolvable in the written `.miz`; member
created when absent).

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Write the key into the mission's `mapResource` member; handle the missing-member case; fix + extend tests | ✅ |

## Impact beyond the kit

`file_static` is exposed to AI assistants as an MCP action, so **any** mission outfitted
that way carried the defect. Not limited to the map-capture kit.

## Definition of Done

- Verified in the DCS editor: the action reads `DO SCRIPT FILE (dcs-bridge.lua)` and the
  FILE field is populated (David, screenshot).
- The kit asset of release 6.11.0 is rebuilt and replaced in place (David's call: keep the
  same version and link rather than cutting 6.11.1).
