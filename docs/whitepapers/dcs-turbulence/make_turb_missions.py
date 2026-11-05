"""Écrit les missions de mesure de la turbulence : une mission vide par réglage, bridge embarqué.

Même base que la mesure du vent (`veaf-survey-Syria.miz`, vide, dcs-bridge chargé au démarrage) et même
réécriture de la météo (`../dcs-wind-model/make_missions.py`). Seuls changent le vent et `groundTurbulence`.

`groundTurbulence` est stocké en dixièmes de m/s : l'éditeur écrit `valeur affichée × 10`
(`MissionEditor/modules/me_weather.lua`, `createTurbulencePanel`) et borne la saisie à 0–6 m/s.

usage: python make_turb_missions.py <veaf-survey-Syria.miz> <dossier de sortie>
"""
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "dcs-wind-model"))
from make_missions import set_weather  # noqa: E402

CALM = ((0, 90), (0, 90), (0, 90))
WIND10 = ((10, 90), (0, 90), (30, 90))  # le vent de la mission 1-reference du modèle du vent

# nom -> (atGround, at2000, at8000, groundTurbulence)
MISSIONS = {
    "t00-calme": (*CALM, 0),
    "t10-calme": (*CALM, 10),
    "t20-calme": (*CALM, 20),
    "t30-calme": (*CALM, 30),
    "t50-calme": (*CALM, 50),
    "t70-calme": (*CALM, 70),
    "t00-vent10": (*WIND10, 0),
    "t20-vent10": (*WIND10, 20),
    "t60-vent10": (*WIND10, 60),
    # relevé long (20 min) : rafale « à la METAR » sur des fenêtres de 10 min, avec un vent moyen
    "t30-vent5": ((5, 90), (0, 90), (15, 90), 30),
}


def main(src: str, out_dir: str) -> None:
    out = Path(out_dir)
    with zipfile.ZipFile(src) as z:
        files = {i.filename: z.read(i.filename) for i in z.infolist()}
    for name, (ground, a2000, a8000, turb) in MISSIONS.items():
        mission = set_weather(files["mission"].decode("utf-8"), ground, a2000, a8000, turb, 20, 6)
        dst = out / f"veaf-turb-{name}.miz"
        with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
            for fn, data in files.items():
                z.writestr(fn, mission.encode("utf-8") if fn == "mission" else data)
        print(dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
