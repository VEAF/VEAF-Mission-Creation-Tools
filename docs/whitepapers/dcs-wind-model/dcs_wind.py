"""Modèle du vent de base DCS World (météo statique), tiré de Weather.dll 2.9.31.29434.

Conventions DCS : x vers le nord, z vers l'est, y altitude MSL.
Dans le .miz, `dir` est la direction VERS laquelle souffle le vent (dir 90 = vent du 270).
"""
import math

KT = 1.943844
GROUND_REF = 45.0 ** 0.2          # addPointGroundWind_w : vent sol (10 m) -> niveau 0 m MSL
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
    """StaticAtmosphere::getBaseWind_w. wind = mission['weather']['wind']. Renvoie (x, z) en m/s."""
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
    """(vitesse m/s, direction D'OÙ vient le vent en degrés)."""
    x, z = xz
    return math.hypot(x, z), (math.degrees(math.atan2(z, x)) + 180.0) % 360.0


if __name__ == "__main__":
    W = {"atGround": {"speed": 9, "dir": 90}, "at2000": {"speed": 11, "dir": 90}, "at8000": {"speed": 14, "dir": 90}}
    measured = {
        "Ramat David": (40, [18, 25, 32, 36, 37, 31]),
        "Rosh Pina": (263, [24, 29, 34, 36, 34, 26]),
        "MASADA": (961, [28, 29, 28, 25, 22, 21]),
    }
    for name, (g, ms) in measured.items():
        row = []
        for agl, m in zip((10, 50, 150, 300, 600, 1000), ms):
            s, _ = speed_from(base_wind(W, g + agl, agl))
            row.append(f"{agl}m: {s*KT:5.1f} (mes {m})")
        print(f"{name:12s} " + " | ".join(row))
