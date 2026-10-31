"""Analyse les relevés de measure_turbulence.py (data/*.json) et imprime un tableau par réglage.

Pour chaque point fixe, sur l'écart d = getWindWithTurbulence - getWind :
- rms horizontal et vertical, p95 et maximum de |d| horizontal ;
- « écart de rafale à la METAR » : maximum de la vitesse horizontale moyennée sur 3 s, moins la vitesse
  moyenne du relevé (la rafale d'un METAR est la pointe sur 3 s de la vitesse, mesurée sur 10 min) ;
- temps de corrélation : premier passage de l'autocorrélation de dx sous 1/e (durée typique d'une rafale) ;
Et sur les coupes spatiales : rms, longueur de corrélation, et déplacement du champ entre les deux coupes.

usage: python analyse_turbulence.py [data/xxx.json ...]   (par défaut, tous les fichiers de data/)
"""
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent


def corr_scale(x: np.ndarray, step: float) -> float:
    """Premier décalage où l'autocorrélation de x passe sous 1/e, en unités de step."""
    x = x - x.mean()
    if not x.any():
        return float("nan")
    ac = np.correlate(x, x, "full")[len(x) - 1:]
    ac = ac / ac[0]
    below = np.nonzero(ac < 1 / np.e)[0]
    return float(below[0] * step) if len(below) else float("inf")


def analyse_point(t: np.ndarray, a: np.ndarray, b: np.ndarray) -> dict:
    """Statistiques d'un point fixe. a, b : vent avec et sans turbulence, (n, 3)."""
    d = a - b
    dh = np.hypot(d[:, 0], d[:, 2])
    dt = float(np.median(np.diff(t)))
    speed = np.hypot(a[:, 0], a[:, 2])
    win = max(1, int(round(3.0 / dt)))
    avg3 = np.convolve(speed, np.ones(win) / win, "valid")
    return {
        "n": len(t), "dt": dt,
        "mean_base": float(np.hypot(b[:, 0], b[:, 2]).mean()),
        "rms_h": float(np.sqrt((dh ** 2).mean())),
        "rms_v": float(np.sqrt((d[:, 1] ** 2).mean())),
        "p95_h": float(np.percentile(dh, 95)), "max_h": float(dh.max()),
        "max_v": float(np.abs(d[:, 1]).max()),
        "gust": float(avg3.max() - speed.mean()),
        "tau": corr_scale(d[:, 0], dt),
    }


def analyse_lines(lines: list) -> list[str]:
    out = []
    for h in sorted({p[0] for p in lines[0]["pts"]}):
        cuts = [np.array([p[2:] for p in ln["pts"] if p[0] == h]) for ln in lines]
        dh = np.hypot(cuts[0][:, 0], cuts[0][:, 2])
        txt = (f"    coupe {h:7.1f} m : rms {np.sqrt((dh ** 2).mean()):.2f} m/s, "
               f"longueur de corrélation {corr_scale(cuts[0][:, 0], 5.0):.0f} m")
        if len(cuts) == 2:
            dt = lines[1]["t"] - lines[0]["t"]
            x0, x1 = cuts[0][:, 0] - cuts[0][:, 0].mean(), cuts[1][:, 0] - cuts[1][:, 0].mean()
            same = float(np.abs(cuts[1] - cuts[0]).max())
            xc = np.correlate(x1, x0, "full")
            lag = (int(np.argmax(xc)) - (len(x0) - 1)) * 5.0
            denom = np.sqrt((x0 ** 2).sum() * (x1 ** 2).sum())
            r = float(xc.max() / denom) if denom else float("nan")
            txt += f" ; {dt:.0f} s plus tard : écart max {same:.2f} m/s, meilleur recalage {lag:+.0f} m (r={r:.2f})"
        out.append(txt)
    return out


def main(paths: list[str]) -> None:
    files = [Path(p) for p in paths] or sorted((HERE / "data").glob("*.json"))
    for f in files:
        rec = json.loads(f.read_text(encoding="utf-8"))
        rows = np.array(rec["rows"])
        w = rec["weather"]
        print(f"\n{f.stem}  groundTurbulence={w['groundTurbulence']:g}  vent sol {w['atGround']['speed']:g} m/s  "
              f"{len(rows)} relevés sur {rows[-1, 0] - rows[0, 0]:.0f} s")
        print("    point            vent  rms_h  rms_v  p95_h  max_h  max_v  rafale3s  tau(s)")
        for i, name in enumerate(rec["points"]):
            c = 1 + 6 * i
            s = analyse_point(rows[:, 0], rows[:, c:c + 3], rows[:, c + 3:c + 6])
            where, h = name.split("|")
            print(f"    {where} {float(h):7.1f} m  {s['mean_base']:5.1f}  {s['rms_h']:5.2f}  {s['rms_v']:5.2f}  "
                  f"{s['p95_h']:5.2f}  {s['max_h']:5.2f}  {s['max_v']:5.2f}  {s['gust']:8.2f}  {s['tau']:6.2f}")
        for line in analyse_lines(rec["lines"]):
            print(line)


if __name__ == "__main__":
    main(sys.argv[1:])
