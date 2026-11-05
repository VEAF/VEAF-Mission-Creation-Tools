"""Écrit les missions de mesure du vent : une mission vide par réglage météo, bridge embarqué.

Part de la mission d'arpentage Syria de veaf-tools (`veaf-survey-Syria.miz`, vide, dcs-bridge chargé au
démarrage) et ne change que la météo. Chaque mission isole une question du modèle.

usage: python make_missions.py <veaf-survey-Syria.miz> <dossier de sortie>
"""
import re
import sys
import zipfile
from pathlib import Path

# nom -> (atGround, at2000, at8000 en (m/s, dir "vers"), groundTurbulence, température, mois)
MISSIONS = {
    # profil complet : facteur sol, exposant selon l'altitude, raccord vers 2000 (nul) puis vers 8000
    "1-reference": ((10, 90), (0, 90), (30, 90), 0, 20, 6),
    # linéarité : vent sol doublé, le reste identique
    "2-double": ((20, 90), (0, 90), (30, 90), 0, 20, 6),
    # interpolation vectorielle ou angulaire : sol vers le nord, 2000 m vers le sud
    "3-opposes": ((10, 0), (10, 180), (10, 180), 0, 20, 6),
    # turbulence, température et saison : tout change sauf le vent de la mission 1
    "4-turbulence-hiver": ((10, 90), (0, 90), (30, 90), 60, -10, 12),
}


def set_weather(mission, ground, a2000, a8000, turb, temp, month):
    i = mission.index("  weather = {")
    head, w = mission[:i], mission[i:]

    def wind(text, key, sd):
        pat = re.compile(r"(%s = \{\s*dir = )[-\d.]+(,\s*speed = )[-\d.]+" % key)
        new, n = pat.subn(lambda m: f"{m.group(1)}{sd[1]}{m.group(2)}{sd[0]}", text)
        assert n == 1, key
        return new

    w = wind(w, "at2000", a2000)
    w = wind(w, "at8000", a8000)
    w = wind(w, "atGround", ground)
    w, n1 = re.subn(r"groundTurbulence = [-\d.]+", f"groundTurbulence = {turb}", w)
    w, n2 = re.subn(r"(season = \{\s*temperature = )[-\d.]+", rf"\g<1>{temp}", w)
    head, n3 = re.subn(r"(date = \{\s*Day = \d+,\s*Month = )\d+", rf"\g<1>{month}", head)
    assert (n1, n2, n3) == (1, 1, 1), (n1, n2, n3)
    return head + w


def main(src, out_dir):
    out_dir = Path(out_dir)
    with zipfile.ZipFile(src) as z:
        files = {i.filename: z.read(i.filename) for i in z.infolist()}
    for name, params in MISSIONS.items():
        mission = set_weather(files["mission"].decode("utf-8"), *params)
        dst = out_dir / f"veaf-wind-{name}.miz"
        with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
            for fn, data in files.items():
                z.writestr(fn, mission.encode("utf-8") if fn == "mission" else data)
        print(dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
