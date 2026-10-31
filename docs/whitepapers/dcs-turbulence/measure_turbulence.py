"""Relève la turbulence DCS dans la mission lancée (via dcs-serve), en points fixes et dans le temps.

Installe dans la mission un échantillonneur (`timer.scheduleFunction`, toutes les 0,05 s) qui lit
`atmosphere.getWindWithTurbulence(p)` et `atmosphere.getWind(p)` en des points fixes au-dessus
d'Abu al-Duhur (terrain plat, 250 m) et de la mer, puis vide son tampon toutes les 15 s pendant la durée
demandée. Prend aussi deux coupes spatiales (une ligne de 10 km) à 60 s d'écart, pour voir si le champ
est figé, se déplace ou se renouvelle.

La météo réellement chargée est relue dans `env.mission.weather` : c'est elle qui fait foi, pas le nom.

usage: python measure_turbulence.py <nom> [--minutes 5] [--client .../dcs-client.yaml]
Écrit data/<nom>.json.
"""
import argparse
import json
import re
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
FT = 0.3048

# hauteurs sol des points fixes, en mètres : 10 m, 100 ft, 500 ft, 1000 ft, 1500 ft, 1000 m
HEIGHTS = [10.0, 100 * FT, 500 * FT, 1000 * FT, 1500 * FT, 1000.0]
SEA_HEIGHTS = [10.0, 1000 * FT]

LUA_START = r'''
local AB = {x = 75929.8, z = 112670.3}            -- Abu al-Duhur
local SEA = coord.LLtoLO(34.5, 35.2, 0)           -- Méditerranée
local g = land.getHeight({x = AB.x, y = AB.z})
local pts, names = {}, {}
for _, h in ipairs({%(heights)s}) do pts[#pts+1] = {x = AB.x, y = g + h, z = AB.z}; names[#names+1] = "sol|" .. h end
for _, h in ipairs({%(sea)s}) do pts[#pts+1] = {x = SEA.x, y = h, z = SEA.z}; names[#names+1] = "mer|" .. h end
if VEAF_TURB then VEAF_TURB.run = false end      -- un seul échantillonneur à la fois
VEAF_TURB = {buf = {}, run = true, pts = pts}
local S = VEAF_TURB
local F = "%%.4f,%%.4f,%%.4f,%%.4f,%%.4f,%%.4f"
local function tick(_, t)
  if not S.run then return nil end
  local row = {string.format("%%.3f", t)}
  for i = 1, #S.pts do
    local p = S.pts[i]
    local a, b = atmosphere.getWindWithTurbulence(p), atmosphere.getWind(p)
    row[#row+1] = string.format(F, a.x, a.y, a.z, b.x, b.y, b.z)
  end
  S.buf[#S.buf+1] = table.concat(row, ";")
  return t + 0.05
end
timer.scheduleFunction(tick, nil, timer.getTime() + 0.05)
local w = env.mission.weather
return string.format("W|%%s|%%s|%%s|%%s|%%s|%%s|%%s|%%s|%%s", w.wind.atGround.speed, w.wind.atGround.dir,
  w.wind.at2000.speed, w.wind.at2000.dir, w.wind.at8000.speed, w.wind.at8000.dir, w.groundTurbulence,
  g, timer.getTime()) .. string.char(10) .. "N|" .. table.concat(names, ";")
'''

LUA_DRAIN = r'''
local b = VEAF_TURB.buf
VEAF_TURB.buf = {}
return table.concat(b, string.char(10))
'''

LUA_STOP = "VEAF_TURB.run = false return 'stopped'"

# coupe spatiale : 2001 points espacés de 5 m le long de x, à 10 m et 1000 ft sol
LUA_LINE = r'''
local AB = {x = 75929.8, z = 112670.3}
local g = land.getHeight({x = AB.x, y = AB.z})
local out = {string.format("%%.3f", timer.getTime())}
for _, h in ipairs({10, %(h1000)s}) do
  for k = 0, 2000 do
    local q = {x = AB.x - 5000 + 5 * k, y = g + h, z = AB.z}
    local a, b = atmosphere.getWindWithTurbulence(q), atmosphere.getWind(q)
    out[#out+1] = string.format("%%s|%%d|%%.4f|%%.4f|%%.4f", h, k, a.x - b.x, a.y - b.y, a.z - b.z)
  end
end
return table.concat(out, string.char(10))
'''


def call(lua: str, client: str) -> str:
    """Exécute du Lua dans la mission par l'API du bridge et renvoie la chaîne retournée."""
    key = re.search(r'api_key:\s*"?([^"\n]+)', Path(client).read_text()).group(1)
    req = urllib.request.Request(
        "http://127.0.0.1:8080/api/exec",
        data=json.dumps({"code": lua, "timeout": 30}).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    res = json.loads(urllib.request.urlopen(req, timeout=60).read())
    if "error" in res:
        raise SystemExit(res["error"])
    return res["result"]


def parse_rows(text: str) -> list[list[float]]:
    rows = []
    for line in text.splitlines():
        if not line:
            continue
        f = line.split(";")
        rows.append([float(f[0])] + [float(x) for cell in f[1:] for x in cell.split(",")])
    return rows


def take_line(client: str) -> dict:
    lines = call(LUA_LINE % {"h1000": 1000 * FT}, client).splitlines()
    pts = []
    for line in lines[1:]:
        h, k, dx, dy, dz = line.split("|")
        pts.append([float(h), int(k), float(dx), float(dy), float(dz)])
    return {"t": float(lines[0]), "pts": pts}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--minutes", type=float, default=5.0)
    ap.add_argument("--client", default="D:/dev/_VEAF/VEAF-dcs-bridge/dcs-client.yaml")
    a = ap.parse_args()

    head = call(LUA_START % {"heights": ", ".join(f"{h:.4f}" for h in HEIGHTS),
                             "sea": ", ".join(f"{h:.4f}" for h in SEA_HEIGHTS)}, a.client)
    w, n = head.splitlines()
    v = [float(x) for x in w.split("|")[1:]]
    rec = {
        "weather": {"atGround": {"speed": v[0], "dir": v[1]}, "at2000": {"speed": v[2], "dir": v[3]},
                    "at8000": {"speed": v[4], "dir": v[5]}, "groundTurbulence": v[6]},
        "ground": v[7], "t_start": v[8],
        "points": n.split("|", 1)[1].split(";"),
        "rows": [], "lines": [],
    }
    print(f"{a.name}: météo chargée {rec['weather']}, sol {rec['ground']:.1f} m, t={rec['t_start']:.1f}")
    rec["lines"].append(take_line(a.client))
    t_end = time.time() + a.minutes * 60
    second_line = time.time() + 60
    while time.time() < t_end:
        time.sleep(15)
        rec["rows"] += parse_rows(call(LUA_DRAIN, a.client))
        if rec["lines"] and len(rec["lines"]) == 1 and time.time() >= second_line:
            rec["lines"].append(take_line(a.client))
        span = rec["rows"][-1][0] - rec["rows"][0][0] if rec["rows"] else 0
        print(f"  {len(rec['rows'])} relevés, {span:.0f} s de temps mission")
    call(LUA_STOP, a.client)
    rec["rows"] += parse_rows(call(LUA_DRAIN, a.client))
    (HERE / "data").mkdir(exist_ok=True)
    (HERE / "data" / f"{a.name}.json").write_text(json.dumps(rec, separators=(",", ":")), encoding="utf-8")
    print(f"écrit data/{a.name}.json")


if __name__ == "__main__":
    main()
