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
position:                    # optional: otherwise, the point of the mission's map
  latitude: 41.93
  longitude: 41.86
  timezone: "Asia/Tbilisi"

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

- **`position:`** says where sunrise and sunset are computed.
  Without it, the build computes them on the mission's map, at one point per theatre (near Batumi on the Caucasus, Hama on Syria…), and says so in the log.
  On a wide map, a mission far from that point is a few minutes off: give `position:` near the mission then.
  A `position:` outside the mission's map (the Damascus of the former default file, left in a Caucasus mission) gets a warning.
- **Times**: `"HH:MM"`, a solar expression (`sunrise`, `sunset-30*60`), or seconds.
  All of them are on the **theatre's local clock**, the one DCS shows: each theatre has a fixed
  offset from UTC, with no daylight saving time (Caucasus UTC+4, Syria UTC+3, GermanyCW UTC+2…).
  The `timezone:` of `position` is only used for a theatre the tool does not know, and the build
  says so.
- **Dates**: `"YYYY-MM-DD"`, `today`, `tomorrow`, `+N` / `-N` days.
- **`metar:`** replaces the `weather:` block with a real observation.

## The wind {#wind}

**`wind_speed` and `wind_direction` are the wind wanted 10 m above a reference airfield**, as a METAR or the ATIS will give it there — not the Mission Editor's setting.
DCS multiplies its "ground wind" by 2.14 at sea level, and reduces it near the ground the less the higher the terrain: 9 m/s set (17 kt) blew 24 kt at 10 m above Rosh Pina and 36 kt at 1,000 ft ([DCS's wind model](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/whitepapers/dcs-wind-model.en.md)).
So the build writes the setting that gives the wanted wind, and its log says for which airfield.

- **The reference airfield** is, in order: the METAR's station when it is on the map; otherwise `reference_airfield`; otherwise the first player group's departure airfield; otherwise sea level, with a warning (the wind will blow stronger over any inland airfield).
- **Aloft**, the 2,000 m wind is 2.2 times the ground setting, veered 20° to the right (`wind_veer`, 0 to 30°); at 8,000 m, 3 m/s more. The wind then only grows with height.
  `wind_speed_2000` / `wind_direction_2000` and `wind_speed_8000` / `wind_direction_8000` (where the wind comes from, degrees) set them by hand; a 2,000 m wind under 2.14 times the ground setting makes a jet 300 to 600 m above the ground, and the build says so.
  Never set an upper wind opposed to the surface one: DCS makes a layer without wind between them.
- **`clearsky: true`** caps the wanted wind at 15 kt, hence the simulated surface wind at the reference airfield, and drops the gusts.
- **Gusts**: a METAR's `G` group (`27015G25KT`), or `wind_gust` (m/s), becomes DCS's turbulence (`groundTurbulence`), from the in-game measurement: a gust gap G over the mean wind takes a turbulence of G / 0.62, capped at 3 m/s. `turbulence` (m/s, as the editor shows it) wins over the gust.

```yaml
versions:
  - name: windy
    time: "10:00"
    weather:
      wind_speed: 7.7           # 15 kt at 10 m above Rosh Pina
      wind_direction: 270.0
      reference_airfield: "Rosh Pina"
      wind_gust: 10.3           # 20 kt
```

The briefing announces the **simulated** wind, layer by layer: the one `inspect_built_mission` and the briefing deck give, and that `veaf-tools dcs mission-check` checks against the briefing, without DCS ([mission-check](../../CLI_REFERENCE.en.md#mission-check)).

## The gotcha {#gotcha}

**The file ships non-empty, so the step runs on your very first build.** Your first mission produces
two `.miz` files without you asking: the one at the root and `missions/…_noon.miz`. Not a duplicate —
the second carries the weather.

Second gotcha: up to 6.29, the shipped `versions.yaml` wrote a `position:` at Damascus, whatever the map.
A mission created before keeps that position, and its "dawn" on the Caucasus comes 25 to 50 minutes after sunrise.
Remove the `position:` block from your `versions.yaml`: the build then computes on the mission's map.

To switch the step off entirely:

```yaml
pipeline:
  weather: false
```

## Going further {#more}

- [Pipeline reference — step 6, weather and time variants](../../PIPELINE_REFERENCE.en.md#pipeline-step-6-versions)
- [Pipeline reference — showing the weather in the briefing](../../PIPELINE_REFERENCE.en.md#briefing-variables)
- [veafWeather](../scripts/veafWeather.en.md) — the weather in game, on the player's side
