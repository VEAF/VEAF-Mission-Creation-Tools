# Mission Maker Guide

Integrate the VEAF Lua framework into your DCS World missions to give players dynamic spawning, combat zones, managed assets, and more — without placing hundreds of units in the editor.

---

## Quick Start — Your First VEAF Mission

### 1. Install the tools

```powershell
# Download veaf-tools-updater.exe from the latest GitHub release and place it in your mission project folder.
.\veaf-tools-updater.exe
```

> **Windows security:** Windows may block `.exe` files downloaded from the internet. If the file doesn't run, right-click it → **Properties** → **General** tab → check **Unblock** at the bottom → **OK**.

This downloads `veaf-tools.exe` and the VEAF Lua scripts to your working directory.

> **Language:** Messages are displayed in your OS language automatically (English or French). To switch language: `veaf-tools.exe user-config --set lang=fr`. See [Language Configuration](GUIDE.md#global-user-configuration).

### 2. Create a mission in DCS Editor

Create a standard `.miz` mission (place your own units, waypoints, weather, etc.). No need to add any VEAF trigger — the build tool handles that.

### 3. Extract the mission

```powershell
veaf-tools.exe extract my-mission.miz
```

This extracts the `.miz` into a mission folder structure (current directory by default) that you can version-control and configure.

### 4. Configure modules

Edit `mission.yaml` at the root of your mission folder to declare which VEAF modules are active and configure assets, combat zones, shortcuts, security, etc.

### 5. Build

```powershell
veaf-tools.exe build my-mission.miz
```

The build tool reads the mission folder, **automatically injects** the VEAF loader trigger, and produces a `.miz` ready to fly with full VEAF MCT functionality.

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
| [Migration Guide](MIGRATION_GUIDE.md) | Converting from VEAF MCT v5 or adding VEAF MCT to an existing mission |
| [Scripts Reference](scripts/README.md) | Per-module documentation with commands and config examples |

