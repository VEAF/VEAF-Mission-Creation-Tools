"""Mesure le vent DCS dans la mission lancée (via dcs-serve) et le compare au modèle de dcs_wind.py.

La mission doit porter le dcs-bridge et dcs-serve doit tourner. La météo de référence est lue dans la
mission elle-même (env.mission.weather), le relevé est écrit en JSON dans data/<nom>.json.

usage: python measure.py <nom> [--client D:/dev/_VEAF/VEAF-dcs-bridge/dcs-client.yaml] [--me]
  --me : appelle aussi Weather.updateSpeedDirForOtherLevel, la fonction qui calcule le champ
         « 500 m » de l'éditeur de mission (require('Weather') : MissionScripting désanitisé requis).
"""
import argparse
import json
import math
import re
import time
import urllib.request
from pathlib import Path

import dcs_wind

HERE = Path(__file__).parent

LUA_PROFILE = r'''
local NL = string.char(10)
local out = {}
local function add(s) out[#out+1] = s end
local w = env.mission.weather
add(string.format("W|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s",
  w.wind.atGround.speed, w.wind.atGround.dir, w.wind.at2000.speed, w.wind.at2000.dir,
  w.wind.at8000.speed, w.wind.at8000.dir, w.groundTurbulence, w.season.temperature,
  env.mission.date.Month, w.atmosphere_type))
local pts = {}
for _, ab in ipairs(world.getAirbases()) do
  if ab:getDesc().category == Airbase.Category.AIRDROME then
    local p = ab:getPoint(); pts[#pts+1] = {ab:getName(), p.x, p.z}
  end
end
local LL = { {"Mer Mediterranee", 34.5, 35.2}, {"Mer Morte", 31.55, 35.48}, {"Lac de Tiberiade", 32.82, 35.59},
             {"Mont Hermon", 33.416, 35.857}, {"Qurnat as Sawda", 34.30, 36.12} }
for _, l in ipairs(LL) do local p = coord.LLtoLO(l[2], l[3], 0); pts[#pts+1] = {l[1], p.x, p.z} end
local AGL = {-5, 0, 1, 2, 5, 10, 11, 20, 50, 100, 200, 300, 400, 499, 500, 501, 600, 800, 1000, 1500, 2000, 3000, 5000}
for _, p in ipairs(pts) do
  local g = land.getHeight({x = p[2], y = p[3]})
  for _, h in ipairs(AGL) do
    local v = atmosphere.getWind({x = p[2], y = g + h, z = p[3]})
    add(string.format("P|%s|%.1f|%.1f|%.2f|%.2f|%.5f|%.5f|%.5f", p[1], p[2], p[3], g, g + h, v.x, v.y, v.z))
  end
end
-- profil MSL fin au-dessus de la mer et d'un point en altitude
for _, i in ipairs({#pts - 4, #pts - 1}) do
  local p = pts[i]
  local g = land.getHeight({x = p[2], y = p[3]})
  for y = -500, 12000, 250 do
    local v = atmosphere.getWind({x = p[2], y = y, z = p[3]})
    add(string.format("P|%s|%.1f|%.1f|%.2f|%.2f|%.5f|%.5f|%.5f", p[1], p[2], p[3], g, y, v.x, v.y, v.z))
  end
end
-- turbulence : une ligne de 300 points espacés de 7 m, a plusieurs hauteurs, au-dessus du premier aerodrome
local p = pts[1]
local g = land.getHeight({x = p[2], y = p[3]})
for _, h in ipairs({10, 100, 500, 1000, 2000}) do
  for k = 0, 299 do
    local q = {x = p[2] + 7 * k, y = g + h, z = p[3]}
    local v = atmosphere.getWindWithTurbulence(q)
    local b = atmosphere.getWind(q)
    add(string.format("T|%d|%d|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f", h, k, v.x, v.y, v.z, b.x, b.y, b.z))
  end
end
-- temperature et pression au-dessus de la mer
local s = pts[#pts - 4]
for y = 0, 12000, 500 do
  local t, pr = atmosphere.getTemperatureAndPressure({x = s[2], y = y, z = s[3]})
  add(string.format("A|%d|%.3f|%.1f", y, t, pr))
end
add(string.format("TIME|%.2f", timer.getTime()))
return table.concat(out, NL)
'''

LUA_ME = r'''
local ok, W = pcall(require, 'Weather')
if not ok then return "ERR|" .. tostring(W) end
local out = {}
for _, sp in ipairs({1, 5, 9, 10, 20}) do
  for _, h in ipairs({11, 100, 250, 500, 1000}) do
    local s, d = W.updateSpeedDirForOtherLevel(11, h, sp, 90)
    out[#out+1] = string.format("ME|%s|%s|%.5f|%.3f", sp, h, s, d)
  end
end
return table.concat(out, string.char(10))
'''


def call(lua, client):
    cfg = Path(client).read_text()
    key = re.search(r'api_key:\s*"?([^"\n]+)', cfg).group(1)
    req = urllib.request.Request(
        "http://127.0.0.1:8080/api/exec",
        data=json.dumps({"code": lua, "timeout": 30}).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    res = json.loads(urllib.request.urlopen(req, timeout=60).read())
    if "error" in res:
        raise SystemExit(res["error"])
    return res["result"]


def parse(text):
    rec = {"P": [], "T": [], "A": [], "ME": []}
    for line in text.splitlines():
        f = line.split("|")
        if f[0] == "W":
            v = [float(x) for x in f[1:]]
            rec["weather"] = {"atGround": {"speed": v[0], "dir": v[1]}, "at2000": {"speed": v[2], "dir": v[3]},
                              "at8000": {"speed": v[4], "dir": v[5]}, "groundTurbulence": v[6],
                              "temperature": v[7], "month": v[8], "atmosphere_type": v[9]}
        elif f[0] == "P":
            rec["P"].append({"name": f[1], "x": float(f[2]), "z": float(f[3]), "ground": float(f[4]),
                             "y": float(f[5]), "v": [float(f[6]), float(f[7]), float(f[8])]})
        elif f[0] == "T":
            rec["T"].append({"h": int(f[1]), "k": int(f[2]), "turb": [float(x) for x in f[3:6]],
                             "base": [float(x) for x in f[6:9]]})
        elif f[0] == "A":
            rec["A"].append({"y": int(f[1]), "T": float(f[2]), "p": float(f[3])})
        elif f[0] == "ME":
            rec["ME"].append({"speed": float(f[1]), "h": float(f[2]), "out_speed": float(f[3]), "out_dir": float(f[4])})
        elif f[0] == "TIME":
            rec["time"] = float(f[1])
        elif f[0] == "ERR":
            rec["ME_error"] = f[1]
    return rec


def compare(rec):
    w = rec["weather"]
    worst = (0.0, None)
    for s in rec["P"]:
        mx, mz = dcs_wind.base_wind(w, s["y"], s["y"] - s["ground"])
        err = math.hypot(mx - s["v"][0], mz - s["v"][2])
        if abs(s["v"][1]) > 1e-6:
            print("composante verticale non nulle :", s)
        if err > worst[0]:
            worst = (err, s)
    print(f"{len(rec['P'])} points de vent comparés, écart maximal au modèle : {worst[0]:.4f} m/s")
    if worst[1]:
        print("   au point", worst[1])
    for h in sorted({t["h"] for t in rec["T"]}):
        d = [math.dist(t["turb"], t["base"]) for t in rec["T"] if t["h"] == h]
        rms = math.sqrt(sum(x * x for x in d) / len(d))
        print(f"turbulence à {h:5d} m sol : écart getWindWithTurbulence - getWind  rms {rms:.3f} m/s  max {max(d):.3f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--client", default="D:/dev/_VEAF/VEAF-dcs-bridge/dcs-client.yaml")
    ap.add_argument("--me", action="store_true")
    a = ap.parse_args()
    t0 = time.time()
    rec = parse(call(LUA_PROFILE, a.client))
    if a.me:
        rec.update({k: v for k, v in parse(call(LUA_ME, a.client)).items() if v})
    (HERE / "data").mkdir(exist_ok=True)
    (HERE / "data" / f"{a.name}.json").write_text(json.dumps(rec, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"relevé écrit en {time.time() - t0:.1f} s : data/{a.name}.json  (météo lue : {rec['weather']})")
    compare(rec)
    for m in rec["ME"]:
        print(f"ME: sol {m['speed']} m/s -> {m['h']} m : {m['out_speed']:.3f} m/s dir {m['out_dir']:.1f}")
    if "ME_error" in rec:
        print("ME:", rec["ME_error"])


if __name__ == "__main__":
    main()
