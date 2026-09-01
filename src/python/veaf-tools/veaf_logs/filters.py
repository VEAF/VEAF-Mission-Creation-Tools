"""Filtrage et recherche.

Trois modes de recherche au choix de l'utilisateur :

* `PLAIN`  texte simple, sous-chaine ;
* `GLOB`   jokers `*` (n'importe quelle suite), `?` (un caractere), `.` litteral ;
* `REGEX`  expression reguliere complete.

Chaque categorie du panneau lateral (niveau, source, famille de bruit) a trois
etats plutot que deux :

* `ON`       ses lignes sont affichees ;
* `OFF`      ses lignes sont masquees ;
* `CONTEXT`  ses lignes n'apparaissent qu'au voisinage d'une ligne retenue,
             comme le `-C` de grep. C'est ce qui permet de ne garder que les
             erreurs tout en voyant ce qui les entoure.

Un critere textuel garde aussi son voisinage : `search_context_lines` donne la
portee commune, et chaque critere peut la surcharger. Le contexte de recherche
*elargit* la recherche, il ne defait pas un filtre : une ligne masquee par son
niveau, sa source ou sa famille de bruit le reste, aussi proche du resultat
soit-elle.

L'evaluation travaille sur des masques binaires (`bytearray`, un octet par
entree) plutot qu'entree par entree : sur un journal d'un million de lignes,
c'est ce qui separe une reponse immediate d'une attente de plusieurs secondes.
"""

from __future__ import annotations

import re
from array import array
from bisect import bisect_left, bisect_right
from dataclasses import dataclass, field
from enum import StrEnum


class Mode(StrEnum):
    PLAIN = "plain"
    GLOB = "glob"
    REGEX = "regex"

    @property
    def label(self) -> str:
        return {"plain": "Texte", "glob": "Jokers", "regex": "Regex"}[self.value]


class State(StrEnum):
    ON = "on"
    OFF = "off"
    CONTEXT = "context"

    @property
    def label(self) -> str:
        return {"on": "affiche", "off": "masque", "context": "contexte"}[self.value]


class PatternError(ValueError):
    """Motif invalide : regex mal formee. Remonte a l'interface pour affichage."""


DEFAULT_CONTEXT_LINES = 3

# Contexte autour d'un resultat de recherche. Nul par defaut : une recherche
# doit rendre ce qu'elle rendait avant que le reglage n'existe.
DEFAULT_SEARCH_CONTEXT_LINES = 0


def _read_optional_span(value: object) -> int | None:
    """Portee lue depuis un fichier de configuration ; `None` si elle n'en est pas une.

    `True` est un entier pour Python : sans le test explicite, un `true` dans le
    JSON passerait pour une portee de 1.
    """
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return max(0, int(value))


def _read_span(value: object, fallback: int) -> int:
    """Meme lecture, avec un repli quand la valeur est absente ou aberrante."""
    found = _read_optional_span(value)
    return fallback if found is None else found


def glob_to_regex(pattern: str) -> str:
    r"""Traduit un motif a jokers en expression reguliere.

    `*` et `?` sont les jokers ; tout le reste, `.` compris, est litteral. On
    n'utilise pas `fnmatch.translate` parce qu'il ancre le motif aux deux bouts
    (il compare des noms de fichiers entiers) alors qu'on cherche une
    sous-chaine dans une ligne de journal.

    >>> glob_to_regex("VEAF*error")
    'VEAF.*error'
    >>> glob_to_regex("v1.?")
    'v1\\..'
    """
    out = []
    for char in pattern:
        if char == "*":
            out.append(".*")
        elif char == "?":
            out.append(".")
        else:
            out.append(re.escape(char))
    return "".join(out)


def pattern_source(pattern: str, mode: Mode) -> str:
    mode = Mode(mode)
    if mode is Mode.PLAIN:
        return re.escape(pattern)
    if mode is Mode.GLOB:
        return glob_to_regex(pattern)
    return pattern


def compile_pattern(pattern: str, mode: Mode, case_sensitive: bool = False) -> re.Pattern | None:
    """Compile un motif selon le mode. Rend None si le motif est vide."""
    if not pattern:
        return None
    flags = 0 if case_sensitive else re.IGNORECASE
    try:
        return re.compile(pattern_source(pattern, mode), flags)
    except re.error as exc:
        raise PatternError(str(exc)) from exc


def compile_pattern_bytes(pattern: str, mode: Mode, case_sensitive: bool = False) -> re.Pattern | None:
    """Version octets du meme motif, pour chercher dans le fichier projete.

    Les journaux DCS sont de l'ASCII ; `IGNORECASE` ne vaut donc que pour
    l'ASCII, ce qui est sans consequence ici.
    """
    if not pattern:
        return None
    flags = 0 if case_sensitive else re.IGNORECASE
    try:
        return re.compile(pattern_source(pattern, mode).encode("utf-8"), flags)
    except (re.error, UnicodeEncodeError) as exc:
        raise PatternError(str(exc)) from exc


@dataclass(slots=True)
class TextFilter:
    """Un critere textuel unique."""

    pattern: str = ""
    mode: Mode = Mode.PLAIN
    case_sensitive: bool = False
    invert: bool = False
    enabled: bool = True
    # Portee du contexte propre a ce critere ; None suit la valeur commune du
    # jeu de filtres. Un 0 explicite n'est donc pas la meme chose que None.
    context_lines: int | None = None

    def __post_init__(self) -> None:
        # `Mode` est une `StrEnum` : Qt la rend telle quelle depuis
        # `currentData()`, donc on peut recevoir une chaine la ou le code
        # compare avec `is`.
        if not isinstance(self.mode, Mode):
            self.mode = Mode(self.mode)

    def compiled(self) -> re.Pattern | None:
        return compile_pattern(self.pattern, self.mode, self.case_sensitive)

    def compiled_bytes(self) -> re.Pattern | None:
        return compile_pattern_bytes(self.pattern, self.mode, self.case_sensitive)

    def describe(self) -> str:
        prefix = "sans " if self.invert else ""
        suffix = "" if self.context_lines is None else f"  ±{self.context_lines}"
        return f"{prefix}{self.mode.label} : {self.pattern}{suffix}"

    def to_dict(self) -> dict:
        return {
            "pattern": self.pattern,
            "mode": self.mode.value,
            "case_sensitive": self.case_sensitive,
            "invert": self.invert,
            "enabled": self.enabled,
            "context_lines": self.context_lines,
        }

    @classmethod
    def from_dict(cls, raw: dict) -> TextFilter:
        return cls(
            pattern=raw["pattern"],
            mode=Mode(raw.get("mode", "plain")),
            case_sensitive=bool(raw.get("case_sensitive", False)),
            invert=bool(raw.get("invert", False)),
            enabled=bool(raw.get("enabled", True)),
            context_lines=_read_optional_span(raw.get("context_lines")),
        )


@dataclass
class FilterSet:
    """Etat complet du filtrage.

    Les dictionnaires ne contiennent que les categories dont l'etat n'est pas
    `ON` : une categorie inconnue — un niveau qui apparait en cours de suivi —
    est donc affichee par defaut, sans qu'on ait eu a la prevoir.
    """

    levels: dict[str, State] = field(default_factory=dict)
    sources: dict[str, State] = field(default_factory=dict)
    noise: dict[str, State] = field(default_factory=dict)
    text_filters: list[TextFilter] = field(default_factory=list)

    # Portee du contexte : une valeur par defaut, et des surcharges par
    # categorie, indexees `"<famille>:<cle>"` — par exemple `"levels:INFO"`.
    # Voir les tarifs d'une categorie donnee par `span_for()`.
    context_lines: int = DEFAULT_CONTEXT_LINES
    context_spans: dict[str, int] = field(default_factory=dict)

    # Meme reglage pour les resultats de recherche : une valeur commune, que
    # chaque `TextFilter` peut surcharger par son propre `context_lines`.
    search_context_lines: int = DEFAULT_SEARCH_CONTEXT_LINES

    # -- consultation -----------------------------------------------------

    def set_state(self, kind: str, key: str, state: State) -> None:
        table = getattr(self, kind)
        if state is State.ON:
            table.pop(key, None)
        else:
            table[key] = state

    @staticmethod
    def span_key(kind: str, key: str) -> str:
        return f"{kind}:{key}"

    def span_for(self, kind: str, key: str) -> int:
        """Portee du contexte pour une categorie, sa surcharge ou le defaut."""
        return self.context_spans.get(self.span_key(kind, key), self.context_lines)

    def set_span(self, kind: str, key: str, span: int | None) -> None:
        """Fixe une portee propre a une categorie ; `None` rend au defaut."""
        composite = self.span_key(kind, key)
        if span is None or span == self.context_lines:
            self.context_spans.pop(composite, None)
        else:
            self.context_spans[composite] = max(0, int(span))

    def search_span(self) -> int:
        """Portee du contexte autour des resultats de recherche.

        La plus large des portees des criteres actifs, meme regle que pour deux
        categories en desaccord : on a demande a voir loin sur au moins un
        critere. Un critere inverse est ecarte — il n'a pas de resultat a
        entourer, il en retire.
        """
        span = 0
        for text_filter in self.text_filters:
            if not text_filter.enabled or not text_filter.pattern or text_filter.invert:
                continue
            own = text_filter.context_lines
            span = max(span, self.search_context_lines if own is None else own)
        return span

    @property
    def uses_context(self) -> bool:
        return any(
            state is State.CONTEXT for table in (self.levels, self.sources, self.noise) for state in table.values()
        )

    @property
    def is_empty(self) -> bool:
        """Aucun critere : le balayage peut etre court-circuite."""
        return (
            not self.levels
            and not self.sources
            and not self.noise
            and not [f for f in self.text_filters if f.enabled and f.pattern]
        )

    # -- persistance ------------------------------------------------------

    def to_dict(self) -> dict:
        return {
            "levels": {key: state.value for key, state in self.levels.items()},
            "sources": {key: state.value for key, state in self.sources.items()},
            "noise": {key: state.value for key, state in self.noise.items()},
            "text_filters": [item.to_dict() for item in self.text_filters],
            "context_lines": self.context_lines,
            "context_spans": dict(self.context_spans),
            "search_context_lines": self.search_context_lines,
        }

    @classmethod
    def from_dict(cls, raw: dict) -> FilterSet:
        def states(name: str) -> dict[str, State]:
            out: dict[str, State] = {}
            for key, value in (raw.get(name) or {}).items():
                try:
                    state = State(value)
                except ValueError:
                    continue
                if state is not State.ON:
                    out[key] = state
            return out

        filters = []
        for item in raw.get("text_filters") or []:
            try:
                filters.append(TextFilter.from_dict(item))
            except (KeyError, ValueError):
                continue
        return cls(
            levels=states("levels"),
            sources=states("sources"),
            noise=states("noise"),
            text_filters=filters,
            context_lines=int(raw.get("context_lines", DEFAULT_CONTEXT_LINES)),
            context_spans={
                str(key): max(0, int(value))
                for key, value in (raw.get("context_spans") or {}).items()
                if isinstance(value, (int, float)) and not isinstance(value, bool)
            },
            search_context_lines=_read_span(raw.get("search_context_lines"), DEFAULT_SEARCH_CONTEXT_LINES),
        )

    def copy(self) -> FilterSet:
        return FilterSet.from_dict(self.to_dict())


def evaluate(store, filters: FilterSet) -> list[int]:
    """Indices des entrees visibles, dans l'ordre du journal.

    Deroulement : on classe d'abord chaque entree en retenue / exclue / de
    contexte selon ses categories, puis on applique les criteres textuels aux
    seules entrees retenues — une ligne de contexte n'a pas a contenir le texte
    cherche, sinon elle n'apporterait rien — et on ajoute enfin les voisinages.

    Les deux voisinages sont distincts et se composent. Celui de la recherche ne
    peut repecher que dans ce que les categories autorisaient *avant* que les
    criteres textuels ne resserrent : sans cette photographie prise a temps, une
    ligne masquee par son niveau reapparaitrait des qu'un resultat tombe a cote,
    et le filtre ne voudrait plus rien dire. Celui des categories passe ensuite,
    sur l'ensemble deja elargi.
    """
    total = len(store)
    if not total:
        return []
    if filters.is_empty:
        return list(range(total))

    kept, spans = _classify(store, filters)
    search_span = filters.search_span()
    allowed = bytes(kept) if search_span else b""

    for text_filter in filters.text_filters:
        if not text_filter.enabled or not text_filter.pattern:
            continue
        _apply_text(store, kept, text_filter)

    if search_span:
        _add_search_context(kept, allowed, search_span)
    if any(spans):
        _add_context(kept, spans)

    return [index for index, visible in enumerate(kept) if visible]


def _classify(store, filters: FilterSet) -> tuple[bytearray, array]:
    """Repartit les entrees entre retenues et candidates au contexte.

    Le second tableau donne, pour chaque entree de contexte, sa portee en
    lignes — 0 signifiant qu'elle n'est pas du contexte. Quand plusieurs
    categories d'une meme entree sont en contexte avec des portees differentes,
    la plus large gagne : on a demande a voir loin sur au moins un critere.
    """
    total = len(store)
    kept = bytearray(total)
    spans = array("i", bytes(4 * total))

    level_states = filters.levels
    source_states = filters.sources
    noise_states = filters.noise
    if not level_states and not source_states and not noise_states:
        return bytearray(b"" * total), spans

    for index in range(total):
        state = State.ON
        span = 0

        if level_states:
            key = store.level_of(index)
            state = _worse(state, level_states.get(key, State.ON))
            if state is State.CONTEXT:
                span = max(span, filters.span_for("levels", key))
        if state is not State.OFF and source_states:
            key = store.source_of(index)
            found = source_states.get(key, State.ON)
            state = _worse(state, found)
            if found is State.CONTEXT:
                span = max(span, filters.span_for("sources", key))
        if state is not State.OFF and noise_states:
            for family in store.noise_of(index):
                found = noise_states.get(family, State.ON)
                state = _worse(state, found)
                if found is State.CONTEXT:
                    span = max(span, filters.span_for("noise", family))
                if state is State.OFF:
                    break

        if state is State.ON:
            kept[index] = 1
        elif state is State.CONTEXT and span > 0:
            spans[index] = span
    return kept, spans


def _worse(current: State, candidate: State) -> State:
    """`OFF` l'emporte sur `CONTEXT`, qui l'emporte sur `ON`."""
    if current is State.OFF or candidate is State.OFF:
        return State.OFF
    if current is State.CONTEXT or candidate is State.CONTEXT:
        return State.CONTEXT
    return State.ON


def _apply_text(store, kept: bytearray, text_filter: TextFilter) -> None:
    """Restreint `kept` aux entrees qui satisfont un critere textuel.

    Le journal est balaye par blocs, et chaque position trouvee est ramenee a
    son entree. Comme les entrees couvrent le fichier sans trou, une
    correspondance situee dans une trace de pile designe bien l'erreur qui la
    porte.
    """
    pattern = text_filter.compiled_bytes()
    if pattern is None:
        return

    found = bytearray(len(kept))
    offsets = store.offsets
    for first, base, data in store.iter_blocks():
        for match in pattern.finditer(data):
            index = bisect_right(offsets, base + match.start(), first) - 1
            if index >= 0:
                found[index] = 1

    if text_filter.invert:
        for index, hit in enumerate(found):
            if hit:
                kept[index] = 0
    else:
        for index, hit in enumerate(found):
            if not hit:
                kept[index] = 0


def _add_search_context(kept: bytearray, allowed: bytes, span: int) -> None:
    """Rouvre le voisinage des resultats de la recherche.

    `allowed` est l'etat de `kept` avant que les criteres textuels ne resserrent :
    une entree ne revient que si les categories la laissaient passer. Les entrees
    ajoutees ne deviennent pas elles-memes des ancres, sans quoi une portee de 1
    finirait par tout ramener de proche en proche.
    """
    anchors = [index for index, visible in enumerate(kept) if visible]
    if not anchors:
        return

    for index, permitted in enumerate(allowed):
        if not permitted or kept[index]:
            continue
        position = bisect_left(anchors, index)
        if position < len(anchors) and anchors[position] - index <= span:
            kept[index] = 1
        elif position and index - anchors[position - 1] <= span:
            kept[index] = 1


def _add_context(kept: bytearray, spans: array) -> None:
    """Ajoute les entrees de contexte assez proches d'une entree retenue.

    On cherche, pour chaque entree de contexte, s'il existe une entree retenue
    a portee — plutot que de balayer le voisinage de chaque entree retenue.
    Avec des portees larges et beaucoup de lignes retenues, la seconde approche
    reparcourt sans cesse les memes intervalles.
    """
    anchors = [index for index, visible in enumerate(kept) if visible]
    if not anchors:
        return

    for index, span in enumerate(spans):
        if not span:
            continue
        position = bisect_left(anchors, index)
        # Ancre la plus proche, avant ou apres.
        if position < len(anchors) and anchors[position] - index <= span:
            kept[index] = 1
        elif position and index - anchors[position - 1] <= span:
            kept[index] = 1


def highlight_patterns(filters: FilterSet) -> list[re.Pattern]:
    """Motifs positifs seuls : ce sont eux qu'on surligne dans le message."""
    out = []
    for text_filter in filters.text_filters:
        if not text_filter.enabled or text_filter.invert or not text_filter.pattern:
            continue
        try:
            pattern = text_filter.compiled()
        except PatternError:
            continue
        if pattern is not None:
            out.append(pattern)
    return out
