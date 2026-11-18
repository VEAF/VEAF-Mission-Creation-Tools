# 04 — recon-render: one ring per group, plural category labels, close rings merged

Status: 🔄 in progress

- Every group is ringed, moving vehicles included (David, 2026-11-17: positions are now read at the grab). `is_mobile_vehicle_group` keeps its use for the briefing's coordinates.
- A group's label is its most frequent category, in the plural: heavy armour, light armour, short/medium/long-range air defence, early-warning radars, surface-to-surface missiles, artillery, infantry, logistics, armed ships, ships, targets.
- A zone made only of statics gets a single ring, "target area"; each ship gets its own ring.
- Rings of the same label closer than a threshold are merged, up to a maximum size.
- `labels` given in the shots file still win.
