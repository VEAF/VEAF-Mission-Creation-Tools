# Mission Maker Guide

Integrate the VEAF Lua framework into your DCS World missions to give players dynamic spawning, combat zones, managed assets, and more — without placing hundreds of units in the editor.

---

## Quick Start — Your First VEAF Mission

### 1. Install the tools

```powershell
# Download veaf-tools-updater.exe from the latest GitHub release, then:
.\veaf-tools-updater.exe update
```

This downloads `veaf-tools.exe` and the VEAF Lua scripts to your working directory.

### 2. Create a mission in DCS Editor

- Create a standard `.miz` mission (place your own units, triggers, etc.)
- Add a **DO SCRIPT FILE** trigger at mission start that loads `veaf-scripts.lua`

### 3. Configure modules

Create a `veaf-mission.yaml` file to declare which VEAF modules are active and configure assets, combat zones, security, etc.

### 4. Build

```powershell
veaf-tools.exe mission-build --source my-mission.miz --output my-mission-veaf.miz
```

The output `.miz` is ready to fly with full VEAF functionality.

---

## What You Can Offer Your Players

| Module | Player experience |
|--------|-------------------|
| [veafSpawn](scripts/veafSpawn.md) | Spawn any unit via F10 markers |
| [veafCasMission](scripts/veafCasMission.md) | Procedural CAS training with difficulty levels |
| [veafCombatZone](scripts/veafCombatZone.md) | Predefined combat areas, activatable on demand |
| [veafAssets](scripts/veafAssets.md) | Managed tankers, AWACS, carriers with auto-respawn |
| [veafCarrierOperations](scripts/veafCarrierOperations.md) | Full carrier recovery workflow |
| [veafQraManager](scripts/veafQraManager.md) | Automatic QRA scramble on intrusion |
| [veafAirWaves](scripts/veafAirWaves.md) | Wave-based air combat missions |
| [veafSecurity](scripts/veafSecurity.md) | Password protection for multiplayer servers |

See the [full scripts catalog](scripts/README.md) for all 17+ modules.

---

## Next Steps

| Document | When to read |
|----------|--------------|
| [Full Guide](GUIDE.md) | Detailed setup, configuration, and build workflow |
| [Migration Guide](MIGRATION_GUIDE.md) | Converting from VEAF v5 or adding VEAF to an existing mission |
| [Scripts Reference](scripts/README.md) | Per-module documentation with commands and config examples |

