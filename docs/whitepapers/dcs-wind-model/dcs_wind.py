"""Vent de base DCS World (météo statique), tel que le calcule Weather.dll 2.9.31.29434.

Conventions DCS : x vers le nord, z vers l'est, y altitude MSL, h hauteur au-dessus du sol.
Dans le .miz, `dir` est la direction VERS laquelle souffle le vent (dir 90 = vent du 270).

En ligne de commande, donne le vent réel par tranche d'altitude au-dessus d'un terrain, pour écrire un brief :

  python dcs_wind.py <mission.miz> --elev-ft 860
  python dcs_wind.py <mission.miz> --elev 263
"""
import argparse
import math
import re
import zipfile

KT = 1.943844
FT = 0.3048
GROUND_REF = 45.0 ** 0.2          # StaticAtmosphere::addPointGroundWind_w : vent sol -> niveau 0 m MSL
LEVELS_Y = (0.0, 2000.0, 8000.0)  # reconfigureAtmosphere : atGround, at2000, at8000


def vec(speed, dir_to_deg):
    a = math.radians(dir_to_deg)
    return (speed * math.cos(a), speed * math.sin(a))


def ground_factor(y, h):
    """IAtmosphere::getWindGroundFactor(y = altitude MSL, h = hauteur sol)."""
    if h >= 500.0:
        return 1.0
    if h <= 0.0:
        return 0.0
    a = min(max(y, 0.0), 1500.0)
    p = 0.2 * (0.9957 - 0.001844 * a + 1.379e-06 * a * a - 3.592e-10 * a * a * a)
    return (h / 500.0) ** p


def base_wind(wind, y, h):
    """StaticAtmosphere::getBaseWind_w. wind = mission.weather.wind. Renvoie (x, z) en m/s."""
    v = [vec(GROUND_REF * wind["atGround"]["speed"], wind["atGround"]["dir"]),
         vec(wind["at2000"]["speed"], wind["at2000"]["dir"]),
         vec(wind["at8000"]["speed"], wind["at8000"]["dir"])]
    if h < 0:
        return (0.0, 0.0)
    if y <= LEVELS_Y[0]:
        f = ground_factor(y, h)
        return (v[0][0] * f, v[0][1] * f)
    if y >= LEVELS_Y[2]:
        return v[2]
    i = 0 if y < LEVELS_Y[1] else 1
    yl, yu = LEVELS_Y[i], LEVELS_Y[i + 1]
    s = (y - yu) / ((yu - yl) * 0.5)
    w = math.exp(-s ** 4)
    f = ground_factor(y, h)
    return tuple((v[i][k] + (v[i + 1][k] - v[i][k]) * w) * f for k in (0, 1))


def speed_from(xz):
    """(vitesse m/s, direction D'OÙ vient le vent, en degrés vrais)."""
    x, z = xz
    return math.hypot(x, z), (math.degrees(math.atan2(z, x)) + 180.0) % 360.0


def read_miz_wind(path):
    """Lit mission.weather.wind dans un .miz (sans interpréteur Lua)."""
    with zipfile.ZipFile(path) as z:
        text = z.read("mission").decode("utf-8")
    w = text[text.rindex("weather = {"):]
    wind = {}
    for key in ("atGround", "at2000", "at8000"):
        m = re.search(r'%s"?\]? = \{\s*\[?"?dir"?\]? = ([-\d.]+),\s*\[?"?speed"?\]? = ([-\d.]+)' % key, w)
        wind[key] = {"dir": float(m.group(1)), "speed": float(m.group(2))}
    return wind


def main():
    ap = argparse.ArgumentParser(description="Vent DCS réel par tranche d'altitude au-dessus d'un terrain.")
    ap.add_argument("miz")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--elev", type=float, help="altitude du terrain, en mètres")
    g.add_argument("--elev-ft", type=float, help="altitude du terrain, en pieds")
    a = ap.parse_args()
    ground = a.elev if a.elev is not None else a.elev_ft * FT
    wind = read_miz_wind(a.miz)
    print("Réglage de la mission : " + ", ".join(
        f"{k} {w['speed']:g} m/s ({w['speed'] * KT:.0f} kt) du {(w['dir'] + 180) % 360:03.0f}" for k, w in wind.items()))
    print(f"Terrain à {ground:.0f} m ({ground / FT:.0f} ft)\n")
    print("  hauteur sol        altitude        vent (du / kt)")
    rows = [(10, "10 m (vent au sol)")] + [(ft * FT, f"{ft} ft") for ft in (100, 300, 500, 1000, 1500, 2000, 3000)]
    for h, label in rows:
        s, d = speed_from(base_wind(wind, ground + h, h))
        print(f"  {label:18s} {(ground + h) / FT:6.0f} ft MSL   {d:03.0f} / {s * KT:4.0f}")
    print()
    for ft in (5000, 6500, 8000, 10000, 15000, 20000, 26000, 30000):
        y = ft * FT
        if y - ground < 500:
            continue
        s, d = speed_from(base_wind(wind, y, y - ground))
        print(f"  {'':18s} {ft:6d} ft MSL   {d:03.0f} / {s * KT:4.0f}")


if __name__ == "__main__":
    main()
