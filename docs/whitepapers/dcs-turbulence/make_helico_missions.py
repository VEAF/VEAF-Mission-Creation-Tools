"""Écrit les missions du test hélico : Abu al-Duhur, vent nul, un hélico de chaque type au sol moteurs tournants.

Part de la mission vide de la mesure (`veaf-survey-Syria.miz`) et y pose les groupes hélico « Template »
d'une mission Open Training (même type, même emport, même carburant), transformés en slots ordinaires.
Une mission par réglage de turbulence ; seul `groundTurbulence` change d'une mission à l'autre.

usage (luadata est dans l'environnement poetry du dépôt) :
  poetry run python make_helico_missions.py <veaf-survey-Syria.miz> <mission OT avec templates> <dossier de sortie>
"""
import copy
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[3] / "src" / "python" / "veaf-tools"))
import luadata  # noqa: E402

AB = (75929.8, 112670.3)  # Abu al-Duhur, le point de la mesure (x nord, y est dans la table de mission)
TYPES = ["UH-1H", "Mi-8MT", "Mi-24P", "Ka-50_3", "SA342M", "OH58D", "AH-64D_BLK_II", "CH-47Fbl1"]
SETTINGS = [0, 20, 30, 40, 50]  # groundTurbulence, en dixièmes de m/s
CJTF_BLUE = 80


def load(miz: str) -> tuple[dict, dict]:
    with zipfile.ZipFile(miz) as z:
        files = {i.filename: z.read(i.filename) for i in z.infolist()}
    return files, luadata.unserialize(files["mission"].decode("utf-8").split("=", 1)[1], encoding="utf-8")


def templates(ot: dict) -> dict[str, dict]:
    found = {}
    for country in ot["coalition"]["blue"]["country"]:
        for g in country.get("helicopter", {}).get("group", []):
            u = g["units"][0]
            if u["skill"] == "Client" and u["type"] in TYPES:
                found.setdefault(u["type"], g)
    return found


def slot(template: dict, n: int) -> dict:
    """Le groupe template en slot au sol, moteurs tournants, à 60 m d'écart vers l'est.

    La rangée est à 1,5 km à l'ouest du centre de la base : terrain plat à 250 m, sans objet à moins de
    150 m (vérifié en jeu par world.searchObjects ; au centre, le CH-47 tombait à 8 m d'un hangar).
    """
    g = copy.deepcopy(template)
    u = g["units"][0]
    x, y = AB[0], AB[1] - 1500 + 60 * n - 210
    name = u["type"]
    g.update({"name": name, "groupId": 9000 + n, "x": x, "y": y, "lateActivation": False, "hidden": False,
              "uncontrolled": False, "start_time": 0})
    u.update({"name": name, "unitId": 9000 + n, "x": x, "y": y, "heading": 0})
    point = g["route"]["points"][0]
    for k in ("airdromeId", "helipadId", "linkUnit", "parking", "parking_id"):
        point.pop(k, None)
        u.pop(k, None)
    point.update({"type": "TakeOffGroundHot", "action": "From Ground Area Hot", "x": x, "y": y, "alt": 0,
                  "alt_type": "RADIO"})
    g["route"]["points"] = [point]
    g["units"] = [u]
    return g


def main(survey: str, ot_miz: str, out_dir: str) -> None:
    files, mission = load(survey)
    found = templates(load(ot_miz)[1])
    missing = [t for t in TYPES if t not in found]
    assert not missing, missing
    mission["coalition"]["blue"]["country"] = [
        {"id": CJTF_BLUE, "name": "CJTF Blue", "helicopter": {"group": [slot(found[t], i) for i, t in enumerate(TYPES)]}}
    ]
    mission["coalitions"]["blue"] = [CJTF_BLUE]
    for turb in SETTINGS:
        mission["weather"]["groundTurbulence"] = turb
        mission["descriptionText"] = f"Test hélico : turbulence {turb / 10:g} m/s (groundTurbulence = {turb}), vent nul."
        lua = luadata.serialize(mission, indent="  ", indent_level=0, always_provide_keyname=True, sort=True)
        dst = Path(out_dir) / f"veaf-turb-helico-{turb // 10}ms.miz"
        with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
            for fn, data in files.items():
                z.writestr(fn, f"mission = \n{lua}".encode() if fn == "mission" else data)
        print(dst)


if __name__ == "__main__":
    main(*sys.argv[1:4])
