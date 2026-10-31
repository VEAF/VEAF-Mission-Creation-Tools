"""Enchaîne les 9 mesures : charge chaque mission par le hook veaf-turb-loader.lua, attend qu'elle réponde
avec la bonne météo, puis lance measure_turbulence.py. DCS doit héberger une partie multijoueur.

usage: python run_all.py [--minutes 5] [--from t00-calme]
"""
import argparse
import subprocess
import sys
import time
from pathlib import Path

from make_turb_missions import MISSIONS
from measure_turbulence import call

HERE = Path(__file__).parent
SAVED = Path.home() / "Saved Games" / "DCS"
CLIENT = "D:/dev/_VEAF/VEAF-dcs-bridge/dcs-client.yaml"
PROBE = "local w = env.mission.weather return w.groundTurbulence .. '|' .. w.wind.atGround.speed .. '|' .. timer.getTime()"


def loaded() -> tuple[float, float, float] | None:
    try:
        turb, wind, t = call(PROBE, CLIENT).split("|")
        return float(turb), float(wind), float(t)
    except BaseException:  # noqa: BLE001 - pas de mission, bridge en reconnexion : on réessaie
        return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--minutes", type=float, default=5.0)
    ap.add_argument("--from", dest="start", default=None)
    a = ap.parse_args()
    names = list(MISSIONS)
    if a.start:
        names = names[names.index(a.start):]
    for name in names:
        turb, wind = MISSIONS[name][3], MISSIONS[name][0][0]
        cur = loaded()
        if not (cur and cur[0] == turb and cur[1] == wind and cur[2] < 120):
            path = SAVED / "Missions" / f"veaf-turb-{name}.miz"
            (SAVED / "Logs" / "veaf-load-request.txt").write_text(str(path) + "\n", encoding="utf-8")
            print(f"{name}: chargement demandé", flush=True)
            time.sleep(15)
            deadline = time.time() + 300
            while True:
                cur = loaded()
                if cur and cur[0] == turb and cur[1] == wind and cur[2] < 120:
                    break
                if time.time() > deadline:
                    sys.exit(f"{name}: la mission ne répond pas avec la bonne météo ({cur})")
                time.sleep(5)
        time.sleep(5)  # laisser la mission s'installer
        subprocess.run([sys.executable, str(HERE / "measure_turbulence.py"), name, "--minutes", str(a.minutes),
                        "--client", CLIENT], check=True)


if __name__ == "__main__":
    main()
