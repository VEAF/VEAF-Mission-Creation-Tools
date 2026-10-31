"""Écart de rafale METAR -> réglage `groundTurbulence` de DCS, d'après la mesure en jeu (dcs-turbulence.fr.md).

Mesuré : un réglage de S m/s (`groundTurbulence = 10 × S`) donne à 10 m sol, sur des fenêtres de 10 min, une
rafale « à la METAR » (pointe de la vitesse moyennée sur 3 s, moins la vitesse moyenne) de 0,62 × S
(0,55 à 0,68 selon la fenêtre). Pour reproduire un écart de rafale G, il faut donc S = G / 0,62.

usage: python gust_to_turbulence.py [plafond_m_s]   (imprime la table, en nœuds et en m/s)
"""
import sys

GUST_PER_SETTING = 0.62  # écart de rafale METAR à 10 m, par m/s de réglage
KT = 0.5144  # m/s par nœud (METAR)
EDITOR_MAX = 6.0  # l'éditeur de mission ne permet pas plus de 6 m/s


def ground_turbulence(gust: float, mean: float, ceiling: float, unit: float = KT) -> int:
    """Réglage `groundTurbulence` (dixièmes de m/s) pour un METAR de vent moyen `mean` et rafale `gust`.

    Args:
        gust: La rafale du METAR (0 ou absente : pas de rafale), dans l'unité `unit`.
        mean: Le vent moyen du METAR, même unité.
        ceiling: Le plafond du réglage, en m/s.
        unit: m/s par unité du METAR (nœuds par défaut ; 1.0 pour un METAR en m/s).

    Returns:
        La valeur à écrire dans `mission.weather.groundTurbulence`.
    """
    excess = max(0.0, gust - mean) * unit if gust else 0.0
    return round(10 * min(excess / GUST_PER_SETTING, ceiling))


def main() -> None:
    ceiling = float(sys.argv[1]) if len(sys.argv) > 1 else EDITOR_MAX
    print(f"plafond {ceiling:g} m/s ; réglage = min(écart / {GUST_PER_SETTING}, plafond)")
    print("écart kt   écart m/s   réglage m/s   groundTurbulence")
    for kt in range(0, 21, 2):
        gt = ground_turbulence(kt, 0, ceiling)
        print(f"{kt:8d}   {kt * KT:9.1f}   {gt / 10:11.1f}   {gt:16d}")


if __name__ == "__main__":
    main()
