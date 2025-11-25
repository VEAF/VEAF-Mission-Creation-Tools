"""README content for weather_and_time_versions module."""

WheatherInjectorREADME = """
# Weather and Time Versions

Create multiple versions of a DCS mission with different weather conditions and start times using a YAML configuration file.

## Features

- **Batch Processing**: Create multiple mission variants from a single base mission
- **Time Flexibility**: Set absolute times or use expressions like `sunrise+30*60`
- **Weather Control**: Inject METAR data or manually set atmospheric conditions
- **Solar Calculations**: Automatic sunrise/sunset calculation for any location
- **Date Management**: Support for absolute dates, relative dates (+1 day), and keywords
- **Lua Conversion**: Convert legacy Lua configurations to YAML format automatically

## Quick Start

### 1. Create Configuration File

Create `missions.yaml`:

```yaml
# Geographic position for solar calculations
position:
  latitude: 33.5
  longitude: 35.5
  timezone: Asia/Damascus

# Base date for all versions
base_date: "2024-03-15"

# Mission variants
versions:
  - name: dawn
    time: "sunrise+30*60"
    metar: "METAR OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018"

  - name: noon
    time: "12:00"
    weather:
      temperature: 25.0
      wind_speed: 8.0
      wind_direction: 270.0

  - name: dusk
    time: "sunset-10*60"
    metar: "METAR OSDI 151420Z 27015G25KT 9999 BKN025 18/12 Q1018"
```

### 2. Run Weather and Time Versions

```bash
veaf-tools weather-and-time base_mission.miz --config-file missions.yaml
```

This creates:
- `dawn.miz` - Mission at sunrise + 30 minutes with METAR weather
- `noon.miz` - Mission at noon with clear skies
- `dusk.miz` - Mission at sunset - 10 minutes with broken clouds

### 3. Convert Legacy Lua Configuration

If you have an old Lua configuration file:

```bash
veaf-tools weather-and-time base_mission.miz --config-file old_config.lua --convert-lua
```

This will:
1. Convert the Lua file to YAML format
2. Ask if you want to create missions from the converted configuration
3. Save the YAML file with the same name as the Lua file

## Configuration Schema

### Root Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `position` | object | No | Geographic position for solar calculations |
| `base_date` | string | No | Base date for all versions (defaults to today) |
| `versions` | array | Yes | List of version configurations |

### Position Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `latitude` | number | Yes | Geographic latitude (-90 to 90) |
| `longitude` | number | Yes | Geographic longitude (-180 to 180) |
| `timezone` | string | Yes | IANA timezone (e.g., "Europe/Paris", "UTC", "Asia/Damascus") |

### Version Configuration

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Output filename (without .miz extension) |
| `time` | string | No | Time expression (see below) |
| `date` | string | No | Date expression (see below) |
| `metar` | string | No | METAR weather string |
| `weather` | object | No | Manual weather parameters |

### Weather Object

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `temperature` | number | -50 to 50 | Air temperature in Celsius |
| `wind_speed` | number | 0+ | Wind speed in m/s |
| `wind_direction` | number | 0-359 | Wind direction in degrees (0=North) |
| `visibility` | number | 0+ | Visibility in meters |
| `cloud_type` | string | clear, few, scattered, broken, overcast | Cloud coverage type |
| `cloud_height` | number | 0+ | Cloud base altitude in meters |
| `fog_enabled` | boolean | true/false | Enable fog effect |

## Time Expressions

Time expressions are parsed into seconds since midnight (0-86400).

### Formats

- **Absolute Time**: `HH:MM` → `14:30` = 52200 seconds
- **Solar References**: `sunrise`, `sunset` (requires `position` in config)
- **Mathematical Expressions**: `sunrise+30*60`, `sunset-10*60` → add/subtract seconds
- **Direct Numbers**: `54000` → exact seconds since midnight

### Examples

```yaml
versions:
  - name: early_morning
    time: "02:00"               # 2 AM

  - name: at_sunrise
    time: "sunrise"             # Calculated from position

  - name: after_sunrise
    time: "sunrise+30*60"       # 30 minutes after sunrise

  - name: before_sunset
    time: "sunset-10*60"        # 10 minutes before sunset

  - name: noon
    time: "12:00"               # Noon
```

## Date Expressions

### Formats

- **ISO Format**: `2024-03-15` → specific date
- **Keywords**: `today`, `tomorrow`, `yesterday`
- **Relative**: `+1`, `-2` → days from base_date

### Examples

```yaml
versions:
  - name: today
    date: "today"

  - name: tomorrow
    date: "tomorrow"

  - name: next_week
    date: "+7"

  - name: last_week
    date: "-7"
```

## METAR Support

When you provide a `metar` field, the module attempts to extract:
- Temperature
- Wind speed and direction
- Visibility
- Cloud coverage and altitude

**Full METAR parsing requires**: `pip install avwx-engine`

Without avwx-engine, basic pattern matching is used for common METAR elements.

## Output

Mission files are created in the same directory as the configuration file, named after each version:

```
missions.yaml          (configuration)
dawn.miz               (created)
noon.miz               (created)
dusk.miz               (created)
```

## Advanced Usage

### Custom Output Directory

```bash
veaf-tools weather-and-time missions.yaml --output-dir ./output_missions
```

### Independent Versions

Versions are processed sequentially, each from the original base mission. Each version is independent.

```yaml
position:
  latitude: 33.5
  longitude: 35.5
  timezone: Asia/Damascus

base_date: "2024-03-15"

versions:
  - name: version1
    time: "08:00"
    date: "2024-03-15"
    weather:
      temperature: 10

  - name: version2
    time: "14:00"
    date: "+1"
    weather:
      temperature: 20
```

### Legacy Lua Configuration

Convert legacy Lua configurations automatically:

```bash
# Convert and review
veaf-tools weather-and-time base_mission.miz --config-file legacy_config.lua --convert-lua

# Direct conversion
veaf-tools weather-and-time base_mission.miz --config-file legacy_config.lua --convert-lua
```

The converter supports the legacy Lua format:

```lua
weatherAndTime = {
  position = {
    lat = 33.5,
    lon = 35.5,
    tz = "Asia/Damascus"
  },
  moments = {
    dawn = "sunrise+30*60",
    noon = "12:00"
  },
  targets = {
    {
      version = "dawn",
      moment = "dawn",
      weather = "METAR OSDI..."
    }
  }
}
```

## Troubleshooting

### "Solar times not calculated"

**Problem**: Using time expressions like `sunrise` without a `position` in config.

**Solution**: Add `position` object with latitude, longitude, and timezone.

### "Mission file not found"

**Problem**: The base mission file specified does not exist.

**Solution**: Check that the mission file path is correct and the file exists.

### "Import astral could not be resolved"

**Problem**: Solar calculation requires the astral library.

**Solution**: Install it with `pip install astral`

### Incorrect weather in created missions

**Problem**: METAR parsing is incomplete without avwx-engine.

**Solution**: Install avwx-engine with `pip install avwx-engine` for full support, or use manual `weather` object instead of `metar`.

### Lua conversion not working

**Problem**: Legacy Lua configuration file format not recognized.

**Solution**: Ensure the Lua file uses the expected format with `weatherAndTime`, `position`, `moments`, and `targets` tables.

## Module Architecture

```
weather_and_time_versions/
├── models/
│   ├── configuration.py    # Data models for YAML parsing
│   └── __init__.py
├── utils/
│   ├── solar_calculator.py       # Sunrise/sunset calculation
│   ├── time_expression_parser.py # Time expression evaluation
│   ├── lua_converter.py          # Legacy Lua to YAML conversion
│   └── __init__.py
├── weather/
│   ├── dcs_weather_converter.py # METAR → DCS weather
│   └── __init__.py
├── weather_and_time_versions_worker.py # Main orchestrator
├── example_configuration.yaml  # Example configuration file
├── __init__.py
└── README.md
```

## See Also

- [WEATHER_AND_TIME_ANALYSIS.md](../WEATHER_AND_TIME_ANALYSIS.md) - Design document and implementation details
"""
