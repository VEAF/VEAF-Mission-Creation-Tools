# Mission Maker Guide

Integrate the VEAF Lua framework into your DCS World missions to give players dynamic spawning, combat zones, managed assets, and more — without placing hundreds of units in the editor.

> **New here?** Read [Discover VMCT in ten minutes](DISCOVER.en.md) for the lay of the land, then
> follow the [tutorial](TUTORIAL.en.md) from an empty folder to a mission that runs. The
> [concept cards](concepts/README.en.md) are what you reopen afterwards, one at a time.

---

## Quick Start — Your First VEAF Mission

### 1. Install the tools

```powershell
# Download veaf-tools-updater.exe from the latest GitHub release and place it in your mission project folder.
.\veaf-tools-updater.exe
```

> **Windows security:** Windows may block `.exe` files downloaded from the internet. If the file doesn't run, right-click it → **Properties** → **General** tab → check **Unblock** at the bottom → **OK**.

This downloads `veaf-tools.exe` and the VEAF Lua scripts to your working directory.

> **Language:** Messages are displayed in your OS language automatically (English or French). To switch language: `veaf-tools.exe user-config --set lang=fr`. See [Language Configuration](GUIDE.en.md#global-user-configuration).

### 2. Create a mission in DCS Editor

Create a standard `.miz` mission (place your own units, waypoints, weather, etc.). No need to add any VEAF trigger — the build tool handles that.

### 3. Extract the mission

```powershell
veaf-tools.exe mission extract my-mission.miz
```

This extracts the `.miz` into a mission folder structure (current directory by default) that you can version-control and configure.

### 4. Configure modules

Edit `mission.yaml` at the root of your mission folder to declare which VEAF modules are active and configure assets, combat zones, shortcuts, security, etc.

### 5. Build

```powershell
veaf-tools.exe mission build my-mission.miz
```

The build tool reads the mission folder, **automatically injects** the VEAF loader trigger, and produces a `.miz` ready to fly with full VEAF MCT functionality.

---

## What You Can Offer Your Players

| Module | Player experience |
|--------|-------------------|
| [veafSpawn](scripts/veafSpawn.en.md) | Spawn any unit via F10 markers |
| [veafCasMission](scripts/veafCasMission.en.md) | Procedural CAS training with difficulty levels |
| [veafCombatZone](scripts/veafCombatZone.en.md) | Predefined combat areas, activatable on demand |
| [veafAssets](scripts/veafAssets.en.md) | Managed tankers, AWACS, carriers with auto-respawn |
| [veafCarrierOperations](scripts/veafCarrierOperations.en.md) | Full carrier recovery workflow |
| [veafQraManager](scripts/veafQraManager.en.md) | Automatic QRA scramble on intrusion |
| [veafAirWaves](scripts/veafAirWaves.en.md) | Wave-based air combat missions |
| [veafSecurity](scripts/veafSecurity.en.md) | Password protection for multiplayer servers |

See the [full scripts catalogue](scripts/README.en.md) for all 17+ modules.

---

## Next Steps

| Document | When to read |
|----------|--------------|
| [Discover VMCT](DISCOVER.en.md) | Ten minutes: what the pieces are and how they fit |
| [Tutorial — your first mission](TUTORIAL.en.md) | One thread, from an empty folder to a mission that runs |
| [Concept cards](concepts/README.en.md) | One short page per concept, with a working example |
| [Full Guide](GUIDE.en.md) | Detailed setup, configuration, and build workflow |
| [Migration Guide](MIGRATION_GUIDE.en.md) | Converting from VEAF MCT v5 or adding VEAF MCT to an existing mission |
| [Scripts Reference](scripts/README.en.md) | Per-module documentation with commands and config examples |
| [AI assistant — install](AI_ASSISTANT_INSTALL.en.md) | Install the Claude Code plugin to create/edit a mission in natural language |
| [AI assistant — catalogue](AI_ASSISTANT_CATALOG.en.md) | What you can ask the AI assistant, in plain language |

