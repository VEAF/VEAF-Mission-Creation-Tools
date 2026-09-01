"""Police d'affichage du journal.

Une seule definition de la police et de sa taille, partagee par la table, le
modele et le panneau de detail. Elle vivait en trois exemplaires — `QFont` etait
construit independamment a chaque endroit, et la hauteur de ligne etait un `18`
ecrit en dur qui supposait le resultat.

Ce module ne depend pas de Qt : la session le lit pour ses valeurs par defaut, et
`veaf_logs` doit rester importable sans PySide6.
"""

from __future__ import annotations

DEFAULT_FONT_FAMILY = "Cascadia Mono"
DEFAULT_FONT_SIZE = 9

# Bornes du zoom. En dessous de 6 points le journal n'est plus lisible, au-dessus
# de 36 une ligne ne tient plus a l'ecran : une molette maintenue ne doit pas
# pouvoir rendre l'outil inutilisable.
MIN_FONT_SIZE = 6
MAX_FONT_SIZE = 36


def clamp_font_size(size: object) -> int:
    """Taille ramenee dans les bornes ; le defaut si ce n'en est pas une.

    Tolerante par choix : la taille vient d'un `session.json` que rien n'empeche
    d'editer a la main, et une valeur aberrante ne doit pas empecher le
    lancement.
    """
    try:
        value = int(size)  # type: ignore[call-overload]
    except (TypeError, ValueError):
        return DEFAULT_FONT_SIZE
    return max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, value))
