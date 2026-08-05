# 01 — Decide the entry point, and write the ADR

Status: ⬜ ready
Type: chore
Files: a new `docs/adr/00NN-*.md`, then this lot's PRD

## The question

A prefab needs two ends: **how content gets selected into one**, and **how it gets placed back out**.
dcs-sms answers both inside the Mission Editor. We rejected the editor
([ADR 0017](../../../docs/adr/0017-no-live-mission-editor-bridge.md)) and cannot copy their code
(GPL v3). So the selection end is ours to invent, and the choice decides the whole lot.

## Candidates to weigh

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

## What the ADR must settle

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

## Licensing discipline

Read their design specs — 68 dated ones, which is what makes rewriting practical — and their
`docs/`. **Do not read `tools/` source to copy structure.** Cite what informed a decision in the ADR,
as `DCS-SMS-EXPLOIT.md` does.

## Acceptance criteria

- [ ] ADR filed, status `accepted` or `rejected`, next free number.
- [ ] If accepted: this lot's PRD gains real tickets, and the gated row in its Scope table is replaced.
- [ ] If rejected: the reason is specific enough that nobody re-explores it, and
      `DCS-SMS-EXPLOIT.md` §4 is annotated with the outcome.
