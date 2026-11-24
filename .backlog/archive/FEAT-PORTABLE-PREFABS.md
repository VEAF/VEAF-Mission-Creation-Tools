# FEAT-PORTABLE-PREFABS — circulate reusable mission content between missions and squadrons

Status: 🚫 wontfix — 2026-10-05. David, on the analysis of the four entry points ticket 01 listed. · archived 2026-11-24

## Why it is closed

Outcome D of ticket 01: the value is real, the entry point costs more than it returns.

- **Nobody asked for it.** The lot comes from studying dcs-sms, not from a squadron's need.
- **The selection front end would have to be invented.** dcs-sms selects inside the Mission Editor, which [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md) rules out, and its code is GPL v3.
- **Reuse is already covered.** The MCP composites (`create_combat_zone`, `create_qra`…) and an agent editing the mission folder place the same content without a second mechanism.

The one idea worth keeping does not need prefabs: warning when a mission uses a unit type from a mod the player may not have.

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §4.

> **This is a design lot, not a port.** One ticket, and it is a decision. The rest cannot be
> specified before it, and pretending otherwise would produce tickets nobody can implement.

## The idea worth having

A **prefab** bundles a selection of mission content — groups, statics, zones, F10 drawings, triggers,
warehouses, base64-embedded media, **and the list of mods it depends on** — and re-instantiates it
elsewhere with an anchor, a rotation and a country. "My FARP with its defences, its logistics zone and
its map drawing" becomes one portable object you drop on another map, facing another way, for another
coalition.

The **distribution** half is the better half of their design: a remote `index.json` manifest, fetched
over HTTPS **non-blocking** (a coroutine pumped by the UI tick, so nothing freezes), a disk cache,
data-only validation of everything that comes down, and an explicit warning when a prefab needs a mod
you do not have. That last point is what makes squadron-to-squadron sharing survivable — without it
you instantiate a prefab and get broken units with no explanation.

## Why VMCT wants this and does not already have it

The MCP domain composites — `create_combat_zone`, `create_qra`, `create_cap_mission` — are already
this idea, but **code-shaped**: a developer writes them, they take parameters, and adding one costs a
lot. A prefab is **data-shaped**: a mission maker selects, saves, shares. Different production model,
complementary rather than redundant, and it scales with the community instead of with our dev time.

Cousin of `ENRICH-DEFAULT-PRESETS`, whose problem is that the shipped default `presets.yaml` defines
only three entries. Prefabs are the general answer to "how does content circulate", of which presets
are one kind.

## The blocker, and it is structural

Their prefabs live in `tools/me-mod/` — a **DCS Mission Editor extension**, ~36 700 lines. Two
independent reasons we cannot follow:

1. **`tools/` is GPL v3.** VMCT is permissive. Nothing under it can be copied; the design specs can be
   read and the ideas rewritten, which is the discipline the whole dcs-sms study runs on.
2. **We rejected the live editor.** [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md)
   closed that on measurements, not taste. So "select things in the editor" — their entire front end —
   is not available to us, and reopening it is not on the table.

So the concept and the distribution design transfer; **the way a mission maker picks what goes into a
prefab has to be invented.** That is a real design question, not a detail, and it decides everything
downstream: the format, where instantiation happens, whether this is a `veaf-tools` command, an MCP
action, or a `mission.yaml` section.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Decide the entry point, and write the ADR](FEAT-PORTABLE-PREFABS.md) | 🚫 |
| — | Format + instantiation, and manifest distribution — **cannot be specified before 01** | — |

## Definition of Done for the lot as it stands

Ticket 01 produces an ADR that either names the entry point and unblocks real tickets, or records
that the idea does not survive contact with our constraints. **Both are acceptable outcomes** — the
second saves the next person from re-reading 36 700 lines of GPL Lua to reach the same conclusion, the
way [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md) did for the editor bridge.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a design lot, not a port**. A prefab bundles mission content — groups, statics, zones, drawings, media *and its mod dependencies* — and re-instantiates it elsewhere with an anchor and a country, which is what the MCP composites already do in code-shape rather than data-shape. Blocked structurally: TUM's version is GPL and leans on the live editor ADR 0017 rejected, so how a mission maker *picks* what goes in has to be invented. **A rejection is an acceptable outcome**

## Tickets, in full

## 01 — Decide the entry point, and write the ADR

Status: 🚫 wontfix — 2026-10-05, outcome D (see the PRD)
Type: chore
Files: a new `docs/adr/00NN-*.md`, then this lot's PRD

### The question

A prefab needs two ends: **how content gets selected into one**, and **how it gets placed back out**.
dcs-sms answers both inside the Mission Editor. We rejected the editor
([ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md)) and cannot copy their code
(GPL v3). So the selection end is ours to invent, and the choice decides the whole lot.

### Candidates to weigh

**A — Extract from a built `.miz` by name.** "Take these groups, statics and zones out of this mission
and save them as a prefab." Nothing new to learn: `read_miz` and the editor-parity layer already reach
all of it. Selection is a list of names, which is awkward for a mission maker with forty groups but
trivial for an agent — and an agent naming things is exactly the `NL-MISSION-GEN` workflow.

**B — An MCP action pair.** `extract_prefab` / `instantiate_prefab`. Same machinery as A, but the
selection problem moves to the conversation: "save the FARP at Incirlik as a prefab" and the agent
resolves the names. Composes with the mutation actions of `FEAT-MCP-MUTATION-ACTIONS`.

**C — A `mission.yaml` section.** Declarative: prefabs listed with an anchor and a rotation, applied at
build. Fits the toolchain's existing shape, and versions in git like everything else. But it only
covers *using* prefabs, not authoring them — you would still need A or B to make one.

**D — Do not do it.** Record that the value is real but the entry point costs more than it returns
given the editor is out.

These are not exclusive: C for consumption plus A or B for authoring is a plausible answer, and
probably the honest one.

### What the ADR must settle

- [ ] Which entry point, and **why the others lose** — with the same discipline as ADR 0017: reasons,
      not preferences.
- [ ] Whether instantiation is design-time (build) or runtime (Lua). Design-time keeps it in the
      toolchain where the projection, naming conventions and validation already live; runtime would
      duplicate all three.
- [ ] What a prefab file **is**: a YAML sidecar per ADR 0016's sidecar precedent, or a zip when media
      is embedded. Base64 media inside a YAML is workable but ugly; a zip needs a data-only reader,
      which `read_miz` already is.
- [ ] The **mod-dependency warning**, which is the one piece of their design worth copying verbatim in
      spirit: a prefab must declare what it needs and instantiation must refuse, or loudly warn, when it
      is missing. Silence here produces broken missions nobody can debug.
- [ ] Whether remote distribution (`index.json` + cache) is in the first iteration at all. Probably not:
      a prefab format that works locally is useful on its own, and a fetcher without a format is not.
- [ ] Rotation semantics. Rotating a group means rotating headings **and** re-laying unit offsets around
      the anchor; the existing `veafUnits.placeGroup` logic is the reference for how a formation is
      arranged, and the geodesic offset from `FEAT-GEO-PLACEMENT` for moving the anchor itself.

### Licensing discipline

Read their design specs — 68 dated ones, which is what makes rewriting practical — and their
`docs/`. **Do not read `tools/` source to copy structure.** Cite what informed a decision in the ADR,
as `DCS-SMS-EXPLOIT.md` does.

### Acceptance criteria

- [ ] ADR filed, status `accepted` or `rejected`, next free number.
- [ ] If accepted: this lot's PRD gains real tickets, and the gated row in its Scope table is replaced.
- [ ] If rejected: the reason is specific enough that nobody re-explores it, and
      `DCS-SMS-EXPLOIT.md` §4 is annotated with the outcome.
