"""Warn when a French text carries no accent (FIX-DEMO-VIDEO-FINDINGS 06).

Two free models' runs wrote accented French through `write` and `edit` and **unaccented** French in the
JavaScript they passed to `execute` (`colonne blindee`, `noeud logistique`, `Detruire`), so the briefing a
player reads looked like a mistake. The tools store accents intact; the text is the model's. A warning, never
a refusal: the text is the caller's, and a short or English one cannot be judged.
"""

from collections.abc import Mapping
from typing import Any

#: Letters a French word takes an accent on; a text holding one is taken as accented.
_ACCENTED = frozenset("àâäçéèêëîïôöùûüÿœæÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸŒÆ")

#: French words as they read without their accents, each of which takes one when written right (``détruire``,
#: ``nœud``, ``arrêtée``), and no word that is also English (``depot``, ``theatre``, ``reservoir``, ``meme``). Two
#: different ones are asked for, so that one word shared with another language proves nothing.
_UNACCENTED_WORDS = frozenset(
    "apres arret arrete arretee arretees arretes blinde blindee blindees blindes defile deja depasse depassee "
    "derniere detruire detruit detruite detruites echelon energie equipe equipes etape etapes etre "
    "eviter evitez frequence frequences immobilisee immobilisees immobilises noeud noeuds "
    "periode precise premiere prevu prevue regroupement repere reperes reseau "
    "securite systeme systemes tres vehicule vehicules".split()
)

#: A text shorter than this is not judged: too few words to tell a missing accent from an English or code string.
_MIN_LENGTH = 40

#: Different unaccented words a text needs before it is called unaccented.
_MIN_WORDS = 2


def _words(text: str) -> set[str]:
    cleaned = "".join(ch.lower() if ch.isalpha() else " " for ch in text)
    return set(cleaned.split())


def missing_accents_warning(label: str, text: str | None) -> str | None:
    """Say so when a text reads as French written without its accents.

    Args:
        label: What the text is (``situation``, ``briefing of zone X``), named in the warning.
        text: The text, or ``None``.

    Returns:
        The warning, or ``None`` when the text has an accent, is too short, or is not French.
    """
    if not text or len(text) < _MIN_LENGTH or any(ch in _ACCENTED for ch in text):
        return None
    found = sorted(_words(text) & _UNACCENTED_WORDS)
    if len(found) < _MIN_WORDS:
        return None
    # An answer to the AI, in English like every action of the catalogue, not a message for the user.
    warning = (
        f"{label}: this text has no accent but reads as French without them ({', '.join(found[:4])}…). What a "
        "player reads keeps its accents (é, è, à, ç, œ…), also inside a tool call; only identifiers — the "
        "mission name, zone and group names — are ASCII. Write it again with its accents."
    )
    return warning


def missing_accents_warnings(texts: Mapping[str, Any]) -> list[str]:
    """The warnings of several texts, the empty and the non-string ones skipped.

    Args:
        texts: ``{label: text}``.

    Returns:
        One warning per text that needs one, in order.
    """
    found = (missing_accents_warning(label, text) for label, text in texts.items() if isinstance(text, str))
    return [warning for warning in found if warning]
