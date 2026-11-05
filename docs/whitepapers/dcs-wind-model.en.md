# DCS: the simulated wind is not the wind set in the mission editor

*VEAF whitepaper for DCS World mission makers and briefing writers.*
*It describes how DCS computes the wind of a static weather from the three values of the mission editor, from the code of `Weather.dll`, checked by in-game measurements.*
*Written on 2026-10-31, DCS 2.9.31.29434, Syria map.*
*Version française : [dcs-wind-model.fr.md](dcs-wind-model.fr.md).*

## Summary

**The editor's "ground wind" is the wind at 10 m only at sea level.**
DCS multiplies it by 2.14 to make a reference wind, then reduces it near the ground, the less so the higher the terrain.
On an airfield 250 m high, the wind at 10 m is 1.34 times the setting; at 1000 m, 1.87 times.
Above the ground, the wind strengthens up to about 2.1 times the setting between 300 and 600 m above the ground, then joins the `at2000` value as it nears 2000 m MSL.

A real case on the mission *Marteau du Golan*: 9 m/s (17 kt) set on the ground, 11 m/s at 2000 m.
The briefing announced 17 kt; DCS simulated 24 kt at 10 m above Rosh Pina, 27 kt at 100 ft and 36 kt at 1000 ft.

What to remember when writing a briefing:

1. never copy the editor's values: compute the real wind with the provided tool (section 7);
2. VMCT's weather reports (ATIS, LASTE) are right, since they query DCS at the right place (section 6);
3. two very different directions on the ground and at 2000 m create a windless layer below 2000 m (section 3.3).

## 1. What is set

In static weather, the mission editor offers three winds, each with a speed and a direction:

| Editor field | `.miz` key | What DCS does with it |
|---|---|---|
| Wind "at 10 m" ("at 33 ft") | `weather.wind.atGround` | a reference wind of 2.141 × the value, placed at 0 m MSL |
| Wind at 2000 m | `weather.wind.at2000` | the value as is, at 2000 m MSL |
| Wind at 8000 m | `weather.wind.at8000` | the value as is, at 8000 m MSL |

In the `.miz` file, `dir` is the direction the wind blows **towards**: `dir = 90` is a westerly wind (from 270).
The editor also shows a "500 m" field, computed and not saved (section 4).

## 2. The model

The base wind (without turbulence) at a point is computed in three steps.
Notation: `y` is the point's altitude MSL, `h` its height above the ground, winds are vectors.

### 2.1 Three levels, in altitude MSL

| Level | Altitude | Vector |
|---|---|---|
| 0 | 0 m MSL | `V0 = 45^0.2 × atGround ≈ 2.1411 × atGround` |
| 1 | 2000 m MSL | `V1 = at2000` |
| 2 | 8000 m MSL | `V2 = at8000` |

The 45^0.2 factor brings a wind measured at about 11 m (500/45 ≈ 11.1 m) up to a reference height of 500 m, through a power law of exponent 0.2.
It is not a unit conversion: it is the exact inverse of the near-ground reduction (section 2.3) at sea level, where the wind at 10 m comes back to 0.98 × the setting.
The inconsistency lies elsewhere: the climb to 500 m always uses the sea-level exponent 0.2, while the descent towards the ground uses an exponent that decreases with altitude.
Over high terrain the reduction no longer offsets the climb, and the ground wind exceeds the setting.

### 2.2 Blending between two levels

Between a lower level (`yl`, `Vl`) and an upper level (`yu`, `Vu`):

```
s = (y − yu) / ((yu − yl) / 2)
w = exp(−s⁴)
V = Vl + (Vu − Vl) × w
```

`s` is −2 at the lower level (w ≈ 0) and 0 at the upper level (w = 1).
The weight stays almost zero over the lower half of the layer, then switches fast: between 0 and 2000 m, the wind keeps 94 % of the gap on the lower side at 700 m MSL, and 63 % at 1000 m MSL.
Below 0 m MSL the wind is `V0`, above 8000 m it is `V2`.
The blend works on the components (north, east), not on the angle: the wind does not turn, it moves from one vector to the other.

### 2.3 Near-ground reduction

Below 500 m above the ground, the vector of step 2.2 is multiplied by:

```
F = (h / 500) ^ p
p = 0.2 × (0.9957 − 0.001844·a + 1.379·10⁻⁶·a² − 3.592·10⁻¹⁰·a³)
a = the point's altitude MSL, clamped to [0; 1500] m
```

`F = 1` from 500 m above the ground, `F = 0` on the ground and below.
The exponent `p` is 0.195 at sea level, 0.073 at 500 m and 0.024 at 1500 m of altitude: **the higher the terrain, the flatter the profile**, so the closer the ground wind is to the reference wind.

The height `h` only drives this reduction; everything else is computed in altitude MSL.

### 2.4 Ratio between the real wind and the "ground" setting

The table gives `2.1411 × F`, that is the ratio between the real wind and `atGround` when the 2000 m level weighs little (low terrain, or `at2000` close to 2.14 × `atGround`).
Above about 700 m MSL, the blend towards `at2000` must be added: use the tool.

| Terrain altitude | at 10 m | at 30 m | at 100 m | at 300 m |
|---|---|---|---|---|
| 0 m | 1.00 | 1.26 | 1.64 | 2.02 |
| 250 m | 1.34 | 1.55 | 1.82 | 2.07 |
| 500 m | 1.61 | 1.76 | 1.94 | 2.09 |
| 750 m | 1.78 | 1.89 | 2.01 | 2.11 |
| 1000 m | 1.87 | 1.95 | 2.04 | 2.11 |
| 1500 m and above | 1.95 | 2.00 | 2.06 | 2.12 |

## 3. What matters and what does not

### 3.1 What matters

- The ground speed, linearly: doubling `atGround` exactly doubles the wind below 2000 m (measured: ratio 2.0000 ± 0.00002).
- The point's altitude MSL, for the exponent `p` and for the blend between levels.
- The height above the ground, below 500 m.

### 3.2 What does not matter for the base wind

Measured (mission 4 against mission 1, difference 0.000000 m/s over 5,392 points):

- the `groundTurbulence` turbulence;
- the temperature;
- the season (month of the mission).

The terrain type (sea, town, forest) appears nowhere in the computation: only the ground altitude does.

### 3.3 Different directions: a windless layer

Mission 3: ground wind towards the north, wind at 2000 m towards the south, 10 m/s each.
Above the sea, measured:

| Altitude MSL | Speed | The wind blows towards |
|---|---|---|
| 500 m | 21.2 m/s | the north |
| 1000 m | 9.9 m/s | the north |
| 1250 m | 1.5 m/s | the south |
| 1500 m | 8.1 m/s | the south |
| 2000 m | 10.0 m/s | the south |

The wind does not turn gradually: it weakens, vanishes around 1100-1200 m and starts again the other way.
By computation (not measured), a 90° difference produces the same effect, less marked: a dip in speed and a rotation packed into a few hundred metres.

### 3.4 Turbulence

`atmosphere.getWind` returns the base wind described here.
`atmosphere.getWindWithTurbulence` adds turbulence to it, present even with `groundTurbulence = 0`: DCS enforces a floor of 2 % of the reference wind `V0`.
Root mean square difference measured between the two functions, over 300 points 7 m apart:

| Height above ground | 10 m/s, turbulence 0 | 10 m/s, turbulence 60 (6 m/s) |
|---|---|---|
| 10 m | 0.66 m/s (max 1.1) | 3.2 m/s (max 5.6) |
| 100 m | 0.28 m/s | 3.0 m/s |
| 500 m | 0.73 m/s | 2.5 m/s |
| 1000 m | 2.1 m/s | 2.5 m/s |
| 2000 m | 0 | 0 |

The detail of the turbulence computation (layers from 20 to 1620 m, cosine decay up to 1500 m) was read in the code but not modelled: it does not change the mean wind to announce in a briefing.

## 4. The mission editor's "500 m" field

Under the ground wind, the editor shows a value "at 500 m" that it recomputes on every change.
It comes from the function `updateSpeedDirForOtherLevel(11, 500, speed, direction)` of the Lua module `Weather` (file `MissionEditor/modules/me_weather.lua`).
Called in game, this function returns a rounded integer, computed at sea level and with no wind at 2000 m:

| Ground wind set | Value shown at 500 m |
|---|---|
| 5 m/s | 11 m/s |
| 9 m/s | 19 m/s |
| 10 m/s | 21 m/s |
| 20 m/s | 43 m/s |

It is a fair order of magnitude of the strongest low-level wind at the seaside, but it ignores `at2000` and the terrain.
Typing a value in this field computes the ground wind back.

## 5. Measurements

Five surveys, each of 5,392 points: the 225 airfields of the Syria map and five geographic points (Mediterranean Sea, Dead Sea, Lake Tiberias, Mount Hermon at 2797 m, Qurnat as Sawda at 2964 m), from −5 to 5000 m above the ground, plus two MSL profiles from −500 to 12,000 m in 250 m steps.
The Dead Sea and Lake Tiberias came out at 3 m of altitude in DCS: no ground below sea level was therefore measured.

| Survey | Setting (ground / 2000 / 8000, m/s) | Question | Largest difference from the model |
|---|---|---|---|
| 0-marteau-5-8-14 | 5 / 8 / 14, from 270 | model on a real weather | 0.0000 m/s |
| 1-reference | 10 / 0 / 30, from 270 | profile shape, blends | 0.0002 m/s |
| 2-double | 20 / 0 / 30, from 270 | linearity | 0.0003 m/s |
| 3-opposes | 10 towards north / 10 towards south / 10 towards south | vector or angular blend | 0.0002 m/s |
| 4-turbulence-hiver | 10 / 0 / 30, turbulence 60, December, −10 °C | turbulence, season, temperature | 0.0002 m/s |

The residual differences come from rounding the surveys to 10⁻⁵ m/s.
The vertical component of the base wind is always zero.
Mission 4, written by script without going through the editor, asked for −10 °C on December 1st; DCS loaded 5 °C.
The editor clamps the temperature to the range the map gives for the date (`Terrain.getTempratureRangeByDate`, in `me_weather.lua`), and the same clamping applies at load time: a temperature typed in the editor is always within the range and is therefore never changed (20 °C and 18 °C were read back as is).
In the editor, on the Syria map in December, the temperature does not go below 5 °C: that is the bound applied.
The temperature decreases by 6.5 °C per 1000 m between 0 and 2000 m, in both seasons.

The raw surveys are in [dcs-wind-model/data/](dcs-wind-model/data/).

## 6. What VMCT does with it

`veafWeather.lua` does not recompute the wind: it queries `atmosphere.getWind` at the wanted point.

- **ATIS and airfield weather report**: wind at 10 m above the ground at the airfield's point, the meteorological definition of surface wind. Measured at Rosh Pina (5 m/s set): VMCT announces 13 kt, DCS simulates 13.1 kt.
- **LASTE** (A-10): wind and temperature at the terrain's altitude + 2000, 8000 and 16,000 ft, rounded to the thousand feet, in magnetic direction.

These values are right with respect to the model.
Two details: the speed is truncated to the knot below (`math.floor`) rather than rounded, and gusts (`getWindWithTurbulence`) are not announced.
The METAR function is commented out and not used.

## 7. Writing a correct briefing

The tool [dcs_wind.py](dcs-wind-model/dcs_wind.py) reads the weather of a `.miz` and gives the real wind above a terrain, without starting DCS:

```
python dcs_wind.py VEAF_Syria_MarteauDuGolan_20261030_TRAINING.miz --elev-ft 860
```

```
Réglage de la mission : atGround 9 m/s (17 kt) du 270, at2000 11 m/s (21 kt) du 270, at8000 14 m/s (27 kt) du 270
Terrain à 262 m (860 ft)

  hauteur sol        altitude        vent (du / kt)
  10 m (vent au sol)    893 ft MSL   270 /   24
  100 ft                960 ft MSL   270 /   27
  300 ft               1160 ft MSL   270 /   32
  500 ft               1360 ft MSL   270 /   34
  1000 ft              1860 ft MSL   270 /   36
  ...
```

(The tool's output is in French: *hauteur sol* is the height above the ground, *vent (du / kt)* the wind, from / knots.)

To aim at a given ground wind on a terrain of known altitude, divide by the ratio of table 2.4: for 15 kt at 10 m on a terrain 250 m high, set 15 / 1.34 ≈ 11 kt (5.8 m/s).
Remember that the wind around 1000 ft above the ground will then be about 2.1 × 11 ≈ 24 kt.

## 8. Repeating the measurements

The scripts are in [dcs-wind-model/](dcs-wind-model/):

- `make_missions.py` writes the four test missions from veaf-tools' empty survey mission (`veaf-survey-Syria.miz`, dcs-bridge loaded at start) by changing only the weather;
- `measure.py <name>` queries the mission run by `dcs-serve`, reads the weather in `env.mission.weather`, saves the survey and prints the difference from the model; `--me` also calls the function of the "500 m" field (a de-sanitised `MissionScripting.lua` is needed for `require`);
- `dcs_wind.py` holds the model.

Protocol: generate the missions, start `dcs-serve`, load each mission in DCS up to the map, run `measure.py`.
One restarted mission per setting: DCS does not allow changing the static weather during a mission.

## 9. How the model was found

The weather code is in `bin/Weather.dll`, whose C++ exports have explicit names (`Weather::StaticAtmosphere`, `IAtmosphere`).
Disassembling (Capstone, script [pedis.py](dcs-wind-model/pedis.py)) four functions is enough:

| Function | Role |
|---|---|
| `reconfigureAtmosphere` | reads `atGround`, `at2000`, `at8000` in the mission and places the points at 0, 2000 and 8000 m |
| `StaticAtmosphere::addPointGroundWind_w` | multiplies the ground wind by `pow(45, 0.2)` and places it at the 0 m level |
| `StaticAtmosphere::getBaseWind_w` | picks the two levels, computes `exp(−s⁴)`, applies the ground factor |
| `IAtmosphere::getWindGroundFactor` | `pow(h/500, p)` with the altitude polynomial |

`IAtmosphere::getGroundWind_w`, used by the user interface, evaluates the base wind at 11 m above the ground.
The in-game measurements confirmed what the code said; they were not used to fit constants.

## 10. Limits

- **Static weather only.** Dynamic weather (`atmosphere_type = 1`, pressure systems) goes through `DynamicAtmosphere::getBaseWind_w`, not studied.
- **One version, one map.** DCS 2.9.31.29434, Syria map; the computation does not depend on the map, but an update of `Weather.dll` can change it. One `measure.py` survey is enough to check.
- **Ground below sea level not measured.** The code applies the `V0` wind there with the sea-level exponent.
- **Single-player measurements**, on the mission engine. The wind felt by an aircraft goes through the same code, but was not measured separately.
- **Turbulence** is only characterised (section 3.4), not modelled.
