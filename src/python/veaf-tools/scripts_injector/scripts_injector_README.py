ScriptsInjectorREADME="""
# VEAF Scripts Injector

The VEAF Scripts Injector is a tool that allows you to inject VEAF scripting framework into DCS mission files. This tool automatically injects all required VEAF Lua scripts and community scripts into your mission, enabling advanced mission functionality and features.

## Command Line Usage

```bash
veaf-tools.exe inject-scripts [OPTIONS] [INPUT_MISSION] [OUTPUT_MISSION]
```

### Arguments

- `INPUT_MISSION`: The DCS mission file (.miz) to edit. Defaults to "mission.miz" if not specified.
- `OUTPUT_MISSION`: The DCS mission file (.miz) to save. Defaults to the same as INPUT_MISSION if not specified.

### Options

- `--verbose`: If set, the script will output detailed debug information.
- `--development-mode`: If set, the mission will dynamically load the scripts from the provided location (via --development-path or in the local node_modules and src/scripts folders).
- `--development-path TEXT`: Path to the development version of the VEAF scripts.
- `--readme`: Provide access to this README documentation.

### Examples

```bash
# Basic usage with default files
veaf-tools.exe inject-scripts

# Specify input and output mission files
veaf-tools.exe inject-scripts my_mission.miz output_mission.miz

# Enable verbose output
veaf-tools.exe inject-scripts --verbose

# Development mode with the current mission scripts (local node_modules and src/scripts folders)
veaf-tools.exe inject-scripts --development-mode

# Development mode with custom scripts path
veaf-tools.exe inject-scripts --development-mode --development-path /path/to/dev/scripts

# Combine options
veaf-tools.exe inject-scripts --verbose --development-mode --development-path /dev/veaf-scripts input.miz output.miz

# View this documentation
veaf-tools.exe inject-scripts --readme
```

## Operating Modes

The VEAF Scripts Injector operates in two distinct modes:

### Static Mode (Default)

In static mode, the tool:
1. Reads all VEAF and community scripts from the expected location
2. Embeds these scripts directly into the mission file
3. Configures the mission to load scripts statically (embedded mode)
4. Creates a self-contained mission file that doesn't require external script files

### Development Mode

In development mode (enabled with `--development-mode`), the tool:
1. Configures the mission to dynamically load scripts from the specified path or from the local node_modules and src/scripts folders
2. Sets up mission variables to point to the development script location
3. Allows for real-time script development without re-injecting scripts
4. If set, the `--development-path` parameter specifies the dynamically loaded script location

## Injected Scripts

The tool automatically injects the following scripts into your mission:

### VEAF Core Scripts
- `veaf.lua` - Core VEAF framework
- `veafTime.lua` - Time and weather management
- `veafAirbases.lua` - Airbase management
- `veafWeather.lua` - Weather control
- `veafAssets.lua` - Asset management
- `veafCarrierOperations.lua` - Carrier operations
- `veafCasMission.lua` - Close Air Support missions
- `veafCombatMission.lua` - Combat mission management
- `veafCombatZone.lua` - Combat zone management
- `veafGrass.lua` - Ground unit spawning
- `veafInterpreter.lua` - Command interpreter
- `veafMarkers.lua` - Map marker management
- `veafMove.lua` - Unit movement
- `veafNamedPoints.lua` - Named point management
- `veafRadio.lua` - Radio management
- `veafSecurity.lua` - Security features
- `veafShortcuts.lua` - Command shortcuts
- `veafSpawn.lua` - Unit spawning
- `veafTransportMission.lua` - Transport missions
- `dcsUnits.lua` - DCS unit definitions
- `veafUnits.lua` - VEAF unit management
- `veafRemote.lua` - Remote operations
- `veafSkynetIadsHelper.lua` - Skynet IADS integration
- `veafSkynetIadsMonitor.lua` - Skynet IADS monitoring
- `veafSanctuary.lua` - Sanctuary management
- `veafQraManager.lua` - Quick Reaction Alert management
- `veafAirwaves.lua` - Communications management
- `veafEventHandler.lua` - Event handling
- `veafCacheManager.lua` - Cache management
- `veafGroundAI.lua` - Ground AI management

### Community Scripts
- `AIEN.lua` - AI Enhancement
- `CSAR.lua` - Combat Search and Rescue
- `CTLD.lua` - Complete Troop and Logistics Deployment
- `DCS-SimpleTextToSpeech.lua` - Text-to-speech functionality
- `Hercules_Cargo.lua` - Hercules cargo operations
- `mist.lua` - Mission Scripting Tools
- `skynet-iads-compiled.lua` - Skynet Integrated Air Defense System
- `TheUniversalMission.lua` - Universal mission framework
- `WeatherMark.lua` - Weather marking system

## Mission Variable Configuration

The tool automatically configures mission variables to control script loading behavior:

### Dictionary Variables
- Variables ending with `-- config`: Set to `true` for dynamic config loading, `false` for static
- Variables ending with `-- scripts`: Set to `true` for dynamic script loading, `false` for static

### Mission Path Variables
- `VEAF_DYNAMIC_MISSIONPATH`: Set to the mission's parent directory
- `VEAF_DYNAMIC_PATH`: Set to the VEAF scripts location (either node_modules or development path)

## How It Works

1. **Mission Loading**: The tool reads the specified DCS mission file (.miz), which is a ZIP archive containing mission data.

2. **Variable Configuration**: It processes the mission's dictionary and trigger rules to set appropriate loading mode variables.

3. **Script Collection**: Depending on the mode:
   - **Static Mode**: Reads all required scripts from the expected location and embeds them in the mission
   - **Development Mode**: Configures dynamic loading paths without embedding scripts

4. **Mission Updates**: Updates mission variables and trigger actions to point to the correct script locations.

5. **Mission Writing**: Saves the modified mission file with the injected scripts (static mode) or updated configuration (development mode).

## File Structure Requirements

### Static Mode
The tool expects to find VEAF scripts in the following location relative to the mission file:
```
mission_directory/
├── mission.miz
└── ../node_modules/veaf-mission-creation-tools/
    └── src/scripts/
        ├── veaf/           # VEAF core scripts
        └── community/      # Community scripts
```

### Development Mode

When using development mode, you specify a custom path containing the same script structure:
```
your_development_path/
└── src/scripts/
    ├── veaf/           # VEAF core scripts
    └── community/      # Community scripts
```

If --development-path is not set, the tool will set the mission to load the scripts dynamically anyway; from:
```
your_mission_path/
└── src/scripts/
    └── missionConfig.lua  # the mission configuration file
└── node_modules/
    └──veaf-mission-creation-tools/ 
       ├── veaf/           # VEAF core scripts
       └── community/      # Community scripts
```

## Error Handling

The tool performs validation on:
- Input mission file existence and format (.miz files only)
- Script directory structure and file existence
- Development path validity (when using development mode and setting the development path)
- Mission file integrity and required sections

If any validation fails, the tool will display an error message and abort the operation.

## Integration with Mission Development

### For Mission Creators
Use static mode to create distributable missions with all scripts embedded:
```bash
veaf-tools.exe inject-scripts --verbose my_mission.miz final_mission.miz
```

Or use development mode to enable rapid iteration during your mission development:
```bash
veaf-tools.exe inject-scripts --development-mode mission.miz
```

This allows you to modify your missionConfig.lua without re-injecting it into the mission file each time.

### For Script Developers
Use development mode to enable rapid iteration during script development:
```bash
veaf-tools.exe inject-scripts --development-mode --development-path /path/to/dev/scripts mission.miz
```

This allows you to modify scripts without re-injecting them into the mission file each time.
"""