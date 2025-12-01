# Weather Injector - YAML Configuration Guide

## Overview

The Weather Injector tool creates multiple mission variants with different weather conditions and start times using YAML configuration files.

## Files

### Configuration Files (YAML)

- **`versions.yaml`** - Defines all mission variants to create
  - Required fields: `versions` (list of version configurations)
  - Optional fields: `position` (for solar calculations), `base_date`

### Example Files

- **`example_configuration.yaml`** - Complete example with all options

## Configuration Structure

### Basic Template

```yaml
position:
  latitude: 33.5
  longitude: 35.5
  timezone: "Asia/Damascus"

base_date: "2024-03-15"

versions:
  - name: version-name
    time: "HH:MM"          # or "sunrise", "sunset", "sunrise+30*60"
    date: "YYYY-MM-DD"     # or "today", "+1", "-7"
    metar: "METAR string"  # optional: METAR weather data
    weather:               # optional: manual weather parameters
      temperature: 25.0
      wind_speed: 8.0
      wind_direction: 270.0
```

## Usage

### Creating Mission Variants

```bash
cd test/weatherAndTime
veaf-tools weather-and-time base_mission.miz --config-file versions.yaml
```

Output:
- `version-name.miz` for each version in the configuration

### Custom Output Directory

```bash
veaf-tools weather-and-time base_mission.miz --config-file versions.yaml --output-dir ./output
```

## Time Expressions

| Expression | Example | Description |
|---|---|---|
| Absolute time | `14:30` | 2:30 PM |
| Sunrise | `sunrise` | Automatic sunrise calculation |
| Sunrise offset | `sunrise+30*60` | 30 minutes after sunrise |
| Sunset offset | `sunset-10*60` | 10 minutes before sunset |
| Seconds | `52200` | Exact seconds since midnight |

Note: `sunrise` and `sunset` require a `position` in the configuration.

## Date Expressions

| Expression | Example | Description |
|---|---|---|
| Absolute date | `2024-03-15` | Specific date (ISO format) |
| Keyword | `today` | Today's date |
| Relative | `+1` | Tomorrow (today + 1 day) |
| Relative past | `-7` | 7 days ago |

## Migration from JSON

Old format (versions.json):
```json
{
  "targets": [
    {
      "version": "dawn-real",
      "realweather": true,
      "moment": "dawn"
    }
  ]
}
```

New format (versions.yaml):
```yaml
versions:
  - name: dawn-real
    time: "sunrise"    # or "sunrise+30*60" for offset
    metar: "..."       # optional: actual METAR weather
```

## Weather Parameters

The `weather` object supports:

| Field | Type | Example |
|-------|------|---------|
| `temperature` | float | `25.0` |
| `wind_speed` | float | `8.0` (m/s) |
| `wind_direction` | float | `270.0` (degrees) |
| `visibility` | float | `10000.0` (meters) |
| `cloud_type` | string | `"clear"`, `"few"`, `"scattered"`, `"broken"`, `"overcast"` |
| `cloud_height` | float | `800.0` (meters) |
| `fog_enabled` | boolean | `false` |

## Position Object (Optional)

For automatic solar calculations:

```yaml
position:
  latitude: 33.5          # -90 to 90
  longitude: 35.5         # -180 to 180
  timezone: "Asia/Damascus"  # IANA timezone
```

Timezone examples:
- `"UTC"`
- `"Europe/Paris"`
- `"Asia/Damascus"`
- `"America/New_York"`

## Examples

### Simple Time Variations

```yaml
versions:
  - name: dawn
    time: "06:00"
  
  - name: noon
    time: "12:00"
  
  - name: dusk
    time: "18:00"
```

### With Real Weather Data

```yaml
position:
  latitude: 42.355691
  longitude: 43.323853
  timezone: "Europe/Moscow"

versions:
  - name: morning-real-weather
    time: "sunrise+60*60"
    metar: "METAR URKA 151530Z 09008KT 9999 FEW020 15/10 Q1020 NOSIG"
  
  - name: afternoon-clear
    time: "14:00"
    weather:
      temperature: 20.0
      wind_speed: 6.0
      wind_direction: 90.0
      cloud_type: "clear"
```

### With Date Variations

```yaml
base_date: "2024-03-15"

versions:
  - name: spring-morning
    date: "today"
    time: "sunrise"
  
  - name: spring-day
    date: "today"
    time: "12:00"
  
  - name: next-week-evening
    date: "+7"
    time: "sunset-30*60"
```

## Tips

1. **Position for Solar Calculations**: Add a `position` block if you want to use `sunrise`/`sunset` expressions. Without it, use explicit times like `"06:00"`.

2. **METAR vs Manual Weather**: 
   - Use `metar` for real weather data from METAR strings
   - Use `weather` object for manual parameter specification

3. **Testing**: Start with explicit times (`"HH:MM"`) before using solar expressions

4. **Timezone**: Use correct IANA timezone names for accurate solar calculations. See [IANA Timezone Database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

5. **Output Naming**: Version `name` fields become the output .miz filenames, so use meaningful names
