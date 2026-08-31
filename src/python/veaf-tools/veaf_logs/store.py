"""Index compact d'un journal.

Le texte reste dans le `Buffer` ; la memoire ne contient que des tableaux
paralleles decrivant chaque entree — environ 30 octets par entree, contre
plus de 700 quand on gardait les chaines. Un journal d'un million de lignes
tient ainsi dans quelques dizaines de mega-octets.

Toute l'indexation travaille sur des octets : les en-tetes DCS et les prefixes
de scripts sont de l'ASCII, et eviter le decodage divise le temps de lecture.
Seules les lignes reellement affichees sont decodees, a la demande.
"""

from __future__ import annotations

from array import array
from bisect import bisect_right

from .buffer import Buffer
from .parser import LEVELS, Entry

LEVEL_INDEX = {name: index for index, name in enumerate(LEVELS)}
UNKNOWN_LEVEL = LEVEL_INDEX["UNKNOWN"]

# Nombre maximal de familles de bruit, impose par le masque binaire 64 bits.
MAX_NOISE_FAMILIES = 64

# Taille des blocs d'indexation : borne la memoire copiee a chaque passe.
_INDEX_CHUNK = 8 << 20

# Taille des blocs de recherche, meme raison.
_SEARCH_CHUNK = 8 << 20


class LogStore:
    """Entrees d'un journal, decrites par tableaux paralleles."""

    def __init__(self, rules, buffer: Buffer) -> None:
        self.rules = rules
        self.buffer = buffer

        self._offset = array("q")  # debut de l'entree dans le fichier
        self._length = array("L")  # longueur totale, continuations comprises
        self._head = array("L")  # longueur de la seule ligne d'en-tete
        self._msg_at = array("H")  # debut du message dans la ligne d'en-tete
        self._level = array("B")
        self._source = array("B")
        self._module = array("H")  # index dans `self.modules`, 0 = aucun
        self._noise = array("Q")  # masque des familles de bruit
        self._lineno = array("L")
        self._conts = array("H")  # nombre de lignes de continuation

        self.modules: list[str] = [""]
        self._module_index: dict[str, int] = {"": 0}

        self._cursor = 0  # octets deja indexes
        self._lines_seen = 0
        self._matchers = _Matchers(rules)

        # Comptages tenus a jour a l'insertion. Les recalculer a la demande
        # imposerait de reparcourir tout l'index a chaque rafraichissement du
        # panneau lateral, ce qui domine largement le cout de l'indexation.
        self._by_level: dict[str, int] = {}
        self._by_source: dict[str, int] = {}
        self._by_noise: dict[str, int] = {}

    # -- taille -----------------------------------------------------------

    def __len__(self) -> int:
        return len(self._offset)

    def clear(self) -> None:
        for tableau in (
            self._offset,
            self._length,
            self._head,
            self._msg_at,
            self._level,
            self._source,
            self._module,
            self._noise,
            self._lineno,
            self._conts,
        ):
            del tableau[:]
        self.modules = [""]
        self._module_index = {"": 0}
        self._cursor = 0
        self._lines_seen = 0
        self._by_level.clear()
        self._by_source.clear()
        self._by_noise.clear()

    # -- indexation -------------------------------------------------------

    def index_new(self, max_bytes: int | None = None) -> int:
        """Indexe ce qui a ete ecrit depuis le dernier appel.

        Rend le nombre d'entrees ajoutees. Une ligne incomplete en fin de
        fichier n'est pas indexee : elle le sera quand sa fin de ligne arrivera.

        `max_bytes` borne le travail d'un appel, pour que l'indexation d'un gros
        journal se decoupe en tranches sans bloquer l'interface.
        """
        size = self.buffer.refresh()
        if size <= self._cursor:
            return 0
        if max_bytes is not None:
            size = min(size, self._cursor + max_bytes)

        before = len(self._offset)
        # On avance par blocs : lire d'un seul tenant les 119 Mo d'un journal
        # de serveur en ferait une copie complete en memoire, ce que tout le
        # reste de cette classe s'emploie a eviter.
        while self._cursor < size:
            base = self._cursor
            data = self.buffer.slice(base, min(_INDEX_CHUNK, size - base))
            # On s'arrete a la derniere fin de ligne : DCS ecrit en continu, la
            # fin du bloc est presque toujours une ligne incomplete.
            cut = data.rfind(b"\n")
            if cut < 0:
                break
            data = data[: cut + 1]
            self._cursor += len(data)

            position = 0
            while True:
                end = data.find(b"\n", position)
                if end < 0:
                    break
                self._add_line(base + position, data[position:end], (end - position) + 1)
                position = end + 1
        return len(self._offset) - before

    def _add_line(self, offset: int, line: bytes, raw_length: int) -> None:
        self._lines_seen += 1
        stripped = line.rstrip(b"\r")
        match = self._matchers.header.match(stripped)

        if match is None and self._matchers.log_opened.match(stripped) is None and self._offset:
            # Ligne sans en-tete : suite de l'entree precedente. On etend sa
            # portee au lieu de creer une entree, pour que la trace de pile
            # reste solidaire de l'erreur qui la porte.
            self._length[-1] += raw_length
            self._conts[-1] += 1
            ajout = self._matchers.noise_mask(stripped, stripped) & ~self._noise[-1]
            if ajout:
                self._noise[-1] |= ajout
                self._count_noise(ajout)
            return

        self._offset.append(offset)
        self._length.append(raw_length)
        self._head.append(len(stripped))
        self._lineno.append(self._lines_seen)
        self._conts.append(0)

        if match is None:
            opened = self._matchers.log_opened.match(stripped) is not None
            self._msg_at.append(0)
            self._level.append(LEVEL_INDEX["INFO"] if opened else UNKNOWN_LEVEL)
            self._source.append(self._matchers.native_source)
            self._module.append(0)
            masque = self._matchers.noise_mask(stripped, stripped)
            self._noise.append(masque)
            self._tally(self._level[-1], self._source[-1], masque)
            return

        message = match.group("message") or b""
        self._msg_at.append(min(match.start("message"), 0xFFFF))
        level = match.group("level")
        source, module, refined = self._matchers.classify(message)
        self._source.append(source)
        self._module.append(self._module_id(module))
        self._level.append(refined if refined is not None else self._matchers.level_id(level))
        masque = self._matchers.noise_mask(stripped, message)
        self._noise.append(masque)
        self._tally(self._level[-1], self._source[-1], masque)

    def _tally(self, level: int, source: int, noise_mask: int) -> None:
        nom = LEVELS[level]
        self._by_level[nom] = self._by_level.get(nom, 0) + 1
        nom = self._matchers.source_id(source)
        self._by_source[nom] = self._by_source.get(nom, 0) + 1
        if noise_mask:
            self._count_noise(noise_mask)

    def _count_noise(self, mask: int) -> None:
        for nom in self._matchers.noise_names(mask):
            self._by_noise[nom] = self._by_noise.get(nom, 0) + 1

    def _module_id(self, module: bytes) -> int:
        if not module:
            return 0
        name = module.decode("ascii", "replace")
        index = self._module_index.get(name)
        if index is None:
            index = len(self.modules)
            self.modules.append(name)
            self._module_index[name] = index
        return index

    # -- lecture ----------------------------------------------------------

    def entry(self, index: int) -> Entry:
        """Reconstitue une entree complete. Decode a la demande."""
        offset = self._offset[index]
        blob = self.buffer.slice(offset, self._length[index])
        text = blob.decode("utf-8", "replace")
        lines = text.splitlines()
        raw = lines[0] if lines else ""
        message_at = self._msg_at[index]

        entry = Entry(
            lineno=self._lineno[index],
            raw=raw,
            level=LEVELS[self._level[index]],
            subsystem="",
            message=raw[message_at:] if message_at else raw,
            source=self._matchers.source_id(self._source[index]),
            module=self.modules[self._module[index]],
            continuations=lines[1:],
        )
        entry.source_label = self._matchers.source_label(self._source[index])
        entry.timestamp = raw[:23] if len(raw) >= 23 and raw[4] == "-" else ""
        entry.noise = self._matchers.noise_names(self._noise[index])
        # Le sous-systeme est une donnee de la ligne : on la releve toujours,
        # meme quand la source affichee est celle d'un script.
        entry.subsystem = self._matchers.subsystem_of(raw)
        if entry.source == "dcs":
            entry.source_label = entry.subsystem or "DCS"
        return entry

    # -- acces aux colonnes, sans construire d'entree ----------------------

    def level_of(self, index: int) -> str:
        return LEVELS[self._level[index]]

    def source_of(self, index: int) -> str:
        return self._matchers.source_id(self._source[index])

    def noise_of(self, index: int) -> tuple[str, ...]:
        return self._matchers.noise_names(self._noise[index])

    @property
    def offsets(self) -> array:
        return self._offset

    @property
    def indexed_bytes(self) -> int:
        """Octets deja indexes : la recherche ne doit pas aller au-dela."""
        return self._cursor

    def index_at_offset(self, position: int) -> int:
        """Entree contenant cette position du fichier."""
        return bisect_right(self._offset, position) - 1

    def iter_blocks(self, max_bytes: int = _SEARCH_CHUNK):
        """Parcourt le journal par blocs, pour une recherche par lots.

        Chaque bloc rend `(index de la premiere entree, offset, octets)` et
        s'arrete sur une frontiere d'entree. Comme une correspondance ne peut
        pas enjamber deux entrees — les motifs ne franchissent pas les fins de
        ligne — aucun resultat n'est perdu au decoupage.
        """
        total = len(self._offset)
        start = 0
        while start < total:
            base = self._offset[start]
            stop = start
            while stop < total and self._offset[stop] + self._length[stop] - base <= max_bytes:
                stop += 1
            if stop == start:
                # Une entree plus grosse que le bloc : on la traite seule.
                stop = start + 1
            end = self._offset[stop - 1] + self._length[stop - 1]
            yield start, base, self.buffer.slice(base, end - base)
            start = stop

    # -- comptages --------------------------------------------------------

    def counts_by_level(self) -> dict[str, int]:
        return dict(self._by_level)

    def counts_by_source(self) -> dict[str, int]:
        return dict(self._by_source)

    def counts_by_noise(self) -> dict[str, int]:
        return dict(self._by_noise)

    # -- reclassement (rechargement du catalogue) --------------------------

    def reclassify(self, rules) -> None:
        """Reapplique un catalogue modifie sans relire le fichier."""
        self.rules = rules
        self._matchers = _Matchers(rules)
        cursor, self._cursor = self._cursor, 0
        self.clear()
        self._cursor = 0
        self.buffer.refresh()
        self.index_new()
        del cursor


class _Matchers:
    """Motifs du catalogue compiles en octets, plus les tables de correspondance."""

    def __init__(self, rules) -> None:
        import re

        from .parser import HEADER_PATTERN, LOG_OPENED_PATTERN

        self.rules = rules
        self.header = re.compile(HEADER_PATTERN.encode("utf-8"))
        self.log_opened = re.compile(LOG_OPENED_PATTERN.encode("utf-8"))

        self.source_ids: list[str] = [source.id for source in rules.sources] + ["dcs"]
        self.source_labels: list[str] = [source.label for source in rules.sources] + ["DCS"]
        self.native_source = len(self.source_ids) - 1

        self._sources = []
        for position, source in enumerate(rules.sources):
            pattern = re.compile(source.pattern.pattern.encode("utf-8"))
            module = (
                re.compile(source.module_pattern.pattern.encode("utf-8")) if source.module_pattern is not None else None
            )
            self._sources.append((position, pattern, module, source))

        if len(rules.noise) > MAX_NOISE_FAMILIES:
            raise ValueError(f"{len(rules.noise)} familles de bruit : le masque en accepte {MAX_NOISE_FAMILIES}")
        self.noise_order = [family.id for family in rules.noise]
        self._noise = [
            (1 << bit, re.compile(family.pattern.pattern.encode("utf-8")), family.on_message)
            for bit, family in enumerate(rules.noise)
        ]
        self._noise_cache: dict[int, tuple[str, ...]] = {0: ()}
        self._subsystem = re.compile(r"^[\d-]{10} [\d:.]+ +\w+ +([\w:]*)")

    # -- classement -------------------------------------------------------

    def classify(self, message: bytes) -> tuple[int, bytes, int | None]:
        """Rend (index de source, nom de module, niveau affine ou None)."""
        for position, pattern, module_pattern, source in self._sources:
            match = pattern.search(message)
            if match is None:
                continue
            module = b""
            if module_pattern is not None:
                found = module_pattern.match(message)
                if found is not None:
                    module = found.group(1)
            return position, module, self._refine(source, match)
        return self.native_source, b"", None

    @staticmethod
    def _refine(source, match) -> int | None:
        """Niveau porte par le prefixe du script, qui prime sur celui de DCS."""
        if source.level_group is None:
            return None
        try:
            token = match.group(source.level_group)
        except (IndexError, KeyError):
            return None
        if not token:
            return None
        name = token.decode("ascii", "replace")
        name = (source.level_map or {}).get(name, name.upper())
        return LEVEL_INDEX.get(name)

    def level_id(self, level: bytes | None) -> int:
        if not level:
            return UNKNOWN_LEVEL
        return LEVEL_INDEX.get(level.decode("ascii", "replace"), UNKNOWN_LEVEL)

    def noise_mask(self, line: bytes, message: bytes) -> int:
        mask = 0
        for bit, pattern, on_message in self._noise:
            if pattern.search(message if on_message else line):
                mask |= bit
        return mask

    def noise_names(self, mask: int) -> tuple[str, ...]:
        cached = self._noise_cache.get(mask)
        if cached is None:
            cached = tuple(name for bit, name in enumerate(self.noise_order) if mask & (1 << bit))
            self._noise_cache[mask] = cached
        return cached

    def source_id(self, index: int) -> str:
        return self.source_ids[index]

    def source_label(self, index: int) -> str:
        return self.source_labels[index]

    def subsystem_of(self, raw: str) -> str:
        match = self._subsystem.match(raw)
        return match.group(1) if match else ""
