---
status: accepted
---

# Sorting injected aircraft groups: structural flag for templates, name prefix for spawnables

When extracting aircraft groups from a `.miz` for re-injection, we must sort each
group into one of two distinct uses: a **spawnable aircraft group** (cloned on
demand at runtime by `veafSpawn`, e.g. `_spawn cap`) or a **dynamic-slot
template** (a model for DCS native Dynamic Slots, consumed by the DCS engine).
We decided to sort on two *different* criteria — a structural flag for templates,
a name prefix for spawnables — and to deliberately abandon the historical
name-based discrimination (`.*[tT]emplate.*`).

## Sort algorithm (at extraction)

For each aircraft group in the mission:

1. `dynSpawnTemplate == true`  → **dynamic-slot template** (C)
2. else if name starts with `veafSpawn-` → **spawnable aircraft group** (B)
3. else → **ignored** (an ordinary mission group: scripted enemies, clients,
   background AI — not a reusable spawn asset)

If a group is *both* (`veafSpawn-…` and `dynSpawnTemplate=true`), the flag wins:
it is treated as a dynamic-slot template.

## Considered options

- **Discriminate by group name** (`.*[tT]emplate.*` for C). **Rejected** — this
  is the historical source of a real bug: a genuine spawnable group whose name
  happened to contain "template" (e.g. `F-15 Template EASY`) was misrouted to the
  dynamic-slot file. Names are author-controlled prose and cannot be trusted as a
  type discriminator.
- **Invent a VEAF-custom metadata field** (e.g. `veafSpawnable = true`) mirroring
  `dynSpawnTemplate`. **Rejected for now** — DCS has no supported way to attach a
  custom field to a group via the Mission Editor UI; it would have to be hand-set
  in the `.miz` and carried by no tool, which is more fragile than a name prefix.

## Why two different criteria (the asymmetry)

Each family is recognised by the marker that is *already its contract with its
consumer*, so the build never invents a second source of truth:

- **(C) dynamic-slot template** → recognised by the **native DCS flag**
  `dynSpawnTemplate`, which the DCS engine itself reads. Robust, name-independent.
- **(B) spawnable aircraft group** → recognised by the **`veafSpawn-` name
  prefix**, which is *already* the runtime contract: `veafSpawn`'s
  `initializeAirUnitTemplates()` only recognises groups prefixed with
  `veafSpawn.AirUnitTemplatesPrefix = "veafSpawn-"`. Using any other build-side
  marker would let build and runtime diverge (a group injected but unspawnable,
  or vice-versa).

## Future note

If David ever finds a reliable way to attach **custom metadata to a DCS group**
(a true structural marker, settable without hand-editing the `.miz`), switch
(B)'s inclusion criterion from the `veafSpawn-` name prefix to that metadata
field, and retire the name test. The name prefix is the best available marker
today, not the ideal one.
