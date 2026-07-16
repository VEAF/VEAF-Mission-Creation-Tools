---
status: accepted
---

# Mission-editing MCP: a separate editor-parity layer, mutating the source `.miz` in place

We are building an MCP server (VMCT-owned, see [FEAT-MCP-MISSION-EDITOR](../../.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md))
so an LLM can edit a DCS mission on a Mission Maker's behalf, and eventually generate one
from a natural-language prompt (`NL-MISSION-GEN`, see `ROADMAP.md` §4).

Two exposed action families, deliberately kept apart: **Editor-parity actions** mutate the
raw `mission.lua` tables inside the source `.miz` directly — one action per thing a human
could do by hand in the DCS Mission Editor (add a group, a trigger, a zone) — bypassing
`mission.yaml` entirely. **VMCT actions** go through the existing declarative
`mission.yaml` → workers pipeline (unchanged). We picked this split over a single
`mission.yaml`-only surface because most of a DCS mission's content (order of battle,
triggers, zones) has no `mission.yaml` representation at all and was never meant to
(`mission.yaml` only configures VEAF *modules*, per [ADR 0001](0001-modules-single-source-of-truth.md)) —
an LLM assisting a Mission Maker needs to drive the same raw surface the Mission Editor
does. We rejected a single composite action per VMCT pattern (e.g. `create_combat_zone`)
for v1: it would require one bespoke action per module (QRA, AirWave, Sanctuary…) and hide
the cross-reference consistency check (`group_validation.py`) that already exists and
already runs at build/validate time — cheaper to reuse than to duplicate per action.

Editor-parity actions write **in place** on the mission's source `.miz` (the file
`convert-v5` and `build` already treat as the live source), each preceded by a timestamped
backup copy — the same safety margin `convert-v5` already relies on, git being the
ultimate net. No action is made idempotent by the tool: calling `add_group` twice creates
two groups, exactly as two clicks in the Mission Editor would — matching editor behaviour
matters more than defensive deduplication, and the calling LLM is expected to inspect
current state first (via a read action reusing the existing `export`/`mission_exporter.py`
JSON contract) before acting, the same way a human looks at the outliner before adding
something.

## Consequences

- No unit-type catalog lives in this MCP; picking concrete DCS unit types stays the
  calling LLM's job (aided by the existing `dcs-reference` agent / `veafUnits` data).
- Zone creation and trigger/trigrule editing are out of scope for the first wave (see the
  PRD); groups/units ship first to let an LLM lay down an order of battle.
- Because actions are primitives, composing a full VEAF construct (e.g. a combat zone)
  takes several calls (add zone + add groups + register the `modules.COMBATZONE` YAML
  entry) orchestrated by the caller — accepted cost for a smaller, reusable catalog.
