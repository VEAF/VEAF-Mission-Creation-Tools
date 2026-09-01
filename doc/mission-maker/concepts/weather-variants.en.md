# Weather variants

## What it is {#what-it-is}

`src/versions.yaml` describes **weather + time** pairs. The build writes one `.miz` per entry, beside
the base mission, under `missions/`. One source mission, several moods.

## The smallest example that works {#minimal-example}

It is the shipped file, cut down to the essentials:

```yaml
versions:
  - name: noon
    time: "12:00"
    weather:
      temperature: 25.0
      wind_speed: 8.0
      wind_direction: 270.0
      visibility: 10000.0
      cloud_type: "clear"
      fog_enabled: false
```

`build My-Mission.miz` then produces `My-Mission.miz` **and** `missions/My-Mission_noon.miz`.

## Solar times and real weather {#solar-and-metar}

```yaml
position:                    # required by solar expressions
  latitude: 33.5
  longitude: 35.5
  timezone: "Asia/Damascus"

base_date: "2024-03-15"

versions:
  - name: dawn
    time: "sunrise"

  - name: evening
    time: "sunset-30*60"     # 30 minutes before sunset

  - name: real-weather
    time: "14:00"
    metar: "METAR OSDI 151420Z 27015G25KT 9999 BKN025 18/12 Q1018 NOSIG"
```

- **Times**: `"HH:MM"`, a solar expression (`sunrise`, `sunset-30*60`), or seconds.
- **Dates**: `"YYYY-MM-DD"`, `today`, `tomorrow`, `+N` / `-N` days.
- **`metar:`** replaces the `weather:` block with a real observation.

## The gotcha {#gotcha}

**The file ships non-empty, so the step runs on your very first build.** Your first mission produces
two `.miz` files without you asking: the one at the root and `missions/…_noon.miz`. Not a duplicate —
the second carries the weather.

Second gotcha: a solar expression with no `position:` block is **skipped silently**. If your "dawn"
variant comes out at the base time, that is where to look.

To switch the step off entirely:

```yaml
pipeline:
  weather: false
```

## Going further {#more}

- [Pipeline reference — step 6, weather and time variants](../../PIPELINE_REFERENCE.en.md#pipeline-step-6-versions)
- [Pipeline reference — showing the weather in the briefing](../../PIPELINE_REFERENCE.en.md#briefing-variables)
- [veafWeather](../scripts/veafWeather.en.md) — the weather in game, on the player's side
