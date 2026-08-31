"""Forme d'une ligne de journal DCS.

Une ligne standard se presente ainsi :

    2026-08-31 11:50:40.872 ERROR   DX11BACKEND (20628): Unknown DLSS preset 'L'
    |__ horodatage ______| |level| |_ subsystem _| |thr| |_______ message ______|

Certaines lignes n'ont pas d'en-tete : les traces de pile Lua qui suivent une
erreur de script, le vidage des informations processeur au demarrage. Elles sont
rattachees a la ligne precedente (`Entry.continuations`) au lieu de flotter
seules, sans quoi un filtre sur ERROR fait disparaitre la trace qui explique
l'erreur.

Ce module ne contient que la description : le decoupage effectif est fait par
`store`, qui recompile ces motifs en octets pour indexer sans decoder.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# En-tete DCS. Le sous-systeme peut contenir '::' (MissionScripting::initialize)
# et le thread vaut 'Main' ou un identifiant numerique. Le ': ' final est parfois
# reduit a ':' quand le message est vide.
#
# Les motifs sont exposes sous forme de chaines : `store` les recompile en
# octets pour indexer sans decoder. Une seule definition, deux emplois.
HEADER_PATTERN = (
    r"^(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2}\.\d+) +"
    r"(?P<level>[A-Z][A-Z_]*) +"
    r"(?P<subsystem>[A-Za-z_][A-Za-z0-9_:]*)? *"
    r"\((?P<thread>[^)]*)\): ?(?P<message>.*)$"
)

# Ligne d'ouverture inseree par DCS en tete de fichier.
LOG_OPENED_PATTERN = r"^=== Log (?P<what>opened|closed) UTC (?P<stamp>.+)$"

LEVELS = ("ALERT", "ERROR", "ERROR_ONCE", "WARNING", "INFO", "DEBUG", "TRACE", "UNKNOWN")


@dataclass(slots=True)
class Entry:
    """Une entree du journal : une ligne d'en-tete et ses eventuelles suites."""

    lineno: int
    raw: str
    timestamp: str = ""
    level: str = "UNKNOWN"
    subsystem: str = ""
    thread: str = ""
    message: str = ""
    source: str = ""  # id de source du catalogue ("veaf", "ctld", ...)
    source_label: str = ""  # libelle affichable ("VEAF", "CTLD", ...)
    module: str = ""  # sous-module d'un script ("GRASS" pour VEAF-GRASS)
    noise: tuple[str, ...] = ()  # ids des familles de bruit qui correspondent
    continuations: list[str] = field(default_factory=list)

    @property
    def text(self) -> str:
        """Ligne complete, suites comprises. C'est ce sur quoi porte la recherche."""
        if not self.continuations:
            return self.raw
        return "\n".join((self.raw, *self.continuations))

    @property
    def time_only(self) -> str:
        """Heure sans la date, pour la colonne du tableau."""
        return self.timestamp[11:] if len(self.timestamp) > 11 else self.timestamp
