# 01 — recon-prepare: names shown last, spawn database checked, zones left alone

Status: 🔄 in progress

- `veaf.HideNamesFromSpawnedGroups = false` goes at the **end** of `veaf-config.lua`, after the mission's own settings.
- The copy no longer activates every combat zone at start: `recon-shoot` activates them one at a time.
- A mission that carries `veaf-spawn-data.lua` but whose triggers never load `VEAF_MapKey_SpawnData` is refused, with the reason.
