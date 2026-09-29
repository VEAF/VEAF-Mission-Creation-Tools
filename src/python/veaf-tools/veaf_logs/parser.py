"""Forme d'une ligne de journal.

Une ligne DCS standard se presente ainsi :

    2026-08-31 11:50:40.872 ERROR   DX11BACKEND (20628): Unknown DLSS preset 'L'
    |__ horodatage ______| |level| |_ subsystem _| |thr| |_______ message ______|

Les autres journaux d'un serveur (DCSServerBot, Real Weather, LotAtc) ont chacun
leur forme d'en-tete, decrite par un `HeaderFormat`. Le format est reconnu ligne
par ligne et non fichier par fichier : le journal de DCSServerBot recopie telle
quelle la sortie de Real Weather au milieu de ses propres lignes.

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

# Niveaux d'une lettre (LotAtc : seuls I et W ont ete releves, les autres
# lettres suivent la meme convention que les prefixes des scripts) et variantes
# de nom : WARN/FATAL/PANIC/DPANIC du journal de Go qu'emploie Real Weather,
# CRITICAL de Python pour DCSServerBot.
_LETTERS = {"T": "TRACE", "D": "DEBUG", "I": "INFO", "W": "WARNING", "E": "ERROR"}
_ALIASES = {"WARN": "WARNING", "FATAL": "ALERT", "PANIC": "ALERT", "DPANIC": "ALERT", "CRITICAL": "ALERT"}


@dataclass(frozen=True, slots=True)
class HeaderFormat:
    """Une forme d'en-tete de ligne.

    Le motif expose les groupes nommes `date`, `time`, `message` et, selon le
    format, `level` et `subsystem`.

    Attributes:
        id: Identifiant stable, repris par la cle `format` des sources de `rules.json`.
        pattern: Expression reguliere de la ligne entiere, ancree en tete.
        level_map: Correspondance entre le niveau ecrit et un nom de `LEVELS`.
        default_level: Niveau d'une ligne dont le format n'en ecrit pas.
        scripts: Les prefixes des scripts Lua (VEAF, CTLD...) s'y appliquent.
            Ce sont des conventions de `dcs.log` : ailleurs, un message qui
            contient « SRS » ne vient pas du script SRS.
    """

    id: str
    pattern: str
    level_map: dict[str, str] = field(default_factory=dict)
    default_level: str = "UNKNOWN"
    scripts: bool = False


# En-tete DCS. Le sous-systeme peut contenir '::' (MissionScripting::initialize)
# et le thread vaut 'Main' ou un identifiant numerique. Le ': ' final est parfois
# reduit a ':' quand le message est vide.
DCS_FORMAT = HeaderFormat(
    id="dcs",
    pattern=(
        r"^(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2}\.\d+) +"
        r"(?P<level>[A-Z][A-Z_]*) +"
        r"(?P<subsystem>[A-Za-z_][A-Za-z0-9_:]*)? *"
        r"\((?P<thread>[^)]*)\): ?(?P<message>.*)$"
    ),
    scripts=True,
)

# Dans l'ordre d'essai : DCS en tete, pour qu'un dcs.log ne paie qu'un essai par
# ligne. Les formats ne se recouvrent pas, l'ordre ne decide donc de rien d'autre.
FORMATS: tuple[HeaderFormat, ...] = (
    DCS_FORMAT,
    # DCSServerBot, journal principal et journal du chat :
    #   2026-09-29 18:09:52.446 DEBUG<tab>message
    # et son journal de performances, virgule et tabulation :
    #   2026-09-29 18:03:38,541<tab>INFO<tab>4.80s<tab>ServerImpl.do_startup()
    HeaderFormat(
        id="dcssb",
        pattern=(
            r"^(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2}[.,]\d+)[ \t]"
            r"(?P<level>[A-Z]+)\t(?P<message>.*)$"
        ),
        level_map=_ALIASES,
    ),
    # Real Weather, dans son fichier et recopie dans celui de DCSServerBot :
    #   2026-09-29T20:03:33.800+0200<tab>WARN<tab>message
    HeaderFormat(
        id="realweather",
        pattern=(
            r"^(?P<date>\d{4}-\d{2}-\d{2})T(?P<time>\d{2}:\d{2}:\d{2}\.\d+)[+-]\d{4}\t"
            r"(?P<level>[A-Z]+)\t(?P<message>.*)$"
        ),
        level_map=_ALIASES,
    ),
    # LotAtc, composant parfois absent :
    #   [2026-09-29 20:05:13 +02:00] [I] [clientserver] message
    #   [2026-07-23 22:00:55 +02:00] [I] --------------------
    # Le composant reste dans le message : « [clienthandler] Init » dit
    # quelque chose, « Init » seul rien.
    HeaderFormat(
        id="lotatc",
        pattern=(
            r"^\[(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2})[^\]]*\] "
            r"\[(?P<level>[A-Z])\] (?P<message>(?:\[(?P<subsystem>[\w.:]+)\] )?.*)$"
        ),
        level_map=_LETTERS,
    ),
    # async_errors.log de DCSServerBot : une exception par bloc, sans niveau.
    #   2026-05-26T00:47:56.023909: Task exception was never retrieved
    HeaderFormat(
        id="dcssb-async",
        pattern=r"^(?P<date>\d{4}-\d{2}-\d{2})T(?P<time>\d{2}:\d{2}:\d{2}\.\d+): (?P<message>.*)$",
        default_level="ERROR",
    ),
    # Journal d'un script, horodatage entre crochets, vide dans les releves :
    #   []  INFO    SCRIPTING: VEAF - I - ACTION  - Initializing module
    HeaderFormat(
        id="bracket",
        pattern=(
            r"^\[(?P<time>[^\]]*)\] +(?P<level>[A-Z][A-Z_]*) +"
            r"(?P<subsystem>[A-Za-z_][A-Za-z0-9_:]*): ?(?P<message>.*)$"
        ),
        scripts=True,
    ),
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
