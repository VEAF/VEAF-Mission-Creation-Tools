"""Index compact d'un journal.

Le texte reste dans le `Buffer` ; la memoire ne contient que des tableaux
paralleles decrivant chaque entree — environ 30 octets par entree, contre
plus de 700 quand on gardait les chaines. Un journal d'un million de lignes
tient ainsi dans quelques dizaines de mega-octets.

Toute l'indexation travaille sur des octets : les en-tetes et les prefixes de
scripts sont de l'ASCII, et eviter le decodage divise le temps de lecture.
Seules les lignes reellement affichees sont decodees, a la demande.
"""

from __future__ import annotations

import re
from array import array
from bisect import bisect_right

from .buffer import Buffer
from .parser import DCS_FORMAT, FORMATS, LEVELS, Entry, HeaderFormat

LEVEL_INDEX = {name: index for index, name in enumerate(LEVELS)}
UNKNOWN_LEVEL = LEVEL_INDEX["UNKNOWN"]

# Nombre maximal de familles de bruit, impose par le masque binaire 64 bits.
MAX_NOISE_FAMILIES = 64

# Format d'une entree sans en-tete reconnu (format inconnu).
NO_FORMAT = 0xFF
_DCS_FORMAT_INDEX = FORMATS.index(DCS_FORMAT)

# Suites qu'une entree peut porter, borne du tableau `_conts` ("H"). Au-dela,
# la ligne ouvre une entree : l'async_errors.log de DCSServerBot en empilait
# 90 000 derriere sa premiere ligne, et l'indexation s'arretait en erreur.
_MAX_CONTINUATIONS = 0xFFFF

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
        self._format = array("B")  # index dans FORMATS, NO_FORMAT sans en-tete

        self.modules: list[str] = [""]
        self._module_index: dict[str, int] = {"": 0}

        self._cursor = 0  # octets deja indexes
        self._lines_seen = 0
        self._max_message = 0  # plus long message rencontre, en caracteres
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
            self._format,
        ):
            del tableau[:]
        self.modules = [""]
        self._module_index = {"": 0}
        self._cursor = 0
        self._lines_seen = 0
        self._max_message = 0
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
        found, match = self._matchers.header(stripped)

        # Ligne sans en-tete apres une entree reconnue : sa suite. On etend sa
        # portee au lieu de creer une entree, pour que la trace de pile reste
        # solidaire de l'erreur qui la porte. Apres une ligne que rien n'a
        # reconnue, en revanche, chaque ligne reste seule : un format inconnu se
        # lit ligne a ligne au lieu de tenir en une entree.
        suite = (
            match is None
            and bool(self._offset)
            and self._format[-1] != NO_FORMAT
            and self._matchers.log_opened.match(stripped) is None
        )
        plein = suite and self._conts[-1] >= _MAX_CONTINUATIONS
        if plein:
            # Compteur plein : la ligne ouvre une entree qui herite du format,
            # du niveau et de la source, pour que les suivantes continuent de
            # s'y rattacher et qu'un filtre sur ERROR garde toute la trace.
            found = self._format[-1]
        elif suite:
            self._length[-1] += raw_length
            self._conts[-1] += 1
            ajout = self._matchers.noise_mask(stripped, stripped, self._format[-1]) & ~self._noise[-1]
            if ajout:
                self._noise[-1] |= ajout
                self._count_noise(ajout)
            return

        self._offset.append(offset)
        self._length.append(raw_length)
        self._head.append(len(stripped))
        self._lineno.append(self._lines_seen)
        self._conts.append(0)
        self._format.append(found)

        if match is None:
            opened = self._matchers.log_opened.match(stripped) is not None
            if opened:
                # La ligne d'ouverture est ecrite par DCS : ce qui la suit s'y
                # rattache, comme avant qu'il y ait plusieurs formats.
                self._format[-1] = _DCS_FORMAT_INDEX
            self._msg_at.append(0)
            # Sans en-tete, la ligne entiere est le message.
            self._max_message = max(self._max_message, len(stripped))
            if plein:
                self._level.append(self._level[-1])
                self._source.append(self._source[-1])
                self._module.append(self._module[-1])
            else:
                self._level.append(LEVEL_INDEX["INFO"] if opened else UNKNOWN_LEVEL)
                self._source.append(self._matchers.native_source)
                self._module.append(0)
            masque = self._matchers.noise_mask(stripped, stripped, found)
            self._noise.append(masque)
            self._tally(self._level[-1], self._source[-1], masque)
            return

        fmt = FORMATS[found]
        message = match.group("message") or b""
        self._msg_at.append(min(match.start("message"), 0xFFFF))
        # En octets, comme `_msg_at` : les journaux sont de l'ASCII pour
        # l'essentiel, et une ligne accentuee ne ferait que reserver la colonne
        # un peu trop large.
        self._max_message = max(self._max_message, len(stripped) - self._msg_at[-1])
        level = self._matchers.level_id(fmt, match.groupdict().get("level"))
        if fmt.scripts:
            source, module, refined = self._matchers.classify(message)
        else:
            source, module, refined = self._matchers.format_source(fmt.id), b"", None
        self._source.append(source)
        self._module.append(self._module_id(module))
        self._level.append(refined if refined is not None else level)
        masque = self._matchers.noise_mask(stripped, message, found)
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
        entry.noise = self._matchers.noise_names(self._noise[index])
        # L'horodatage et le sous-systeme sont des donnees de la ligne : on les
        # releve toujours, meme quand la source affichee est celle d'un script.
        entry.timestamp, entry.subsystem = self._matchers.stamp_of(self._format[index], raw)
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
    def max_message_length(self) -> int:
        """Longueur du plus long message, pour dimensionner la colonne.

        Tenue a l'indexation : demander sa largeur a Qt reviendrait a mesurer un
        echantillon de lignes, donc a donner une largeur qui saute au defilement.
        """
        return self._max_message

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

        from .parser import LOG_OPENED_PATTERN

        self.rules = rules
        self._headers = [re.compile(fmt.pattern.encode("utf-8")) for fmt in FORMATS]
        # Versions texte, pour relever l'horodatage d'une entree affichee.
        self._headers_text = [re.compile(fmt.pattern) for fmt in FORMATS]
        self.log_opened = re.compile(LOG_OPENED_PATTERN.encode("utf-8"))

        self.source_ids: list[str] = [source.id for source in rules.sources] + ["dcs"]
        self.source_labels: list[str] = [source.label for source in rules.sources] + ["DCS"]
        self.native_source = len(self.source_ids) - 1

        self._by_format: dict[str, int] = {}
        self._sources = []
        for position, source in enumerate(rules.sources):
            for format_id in source.formats:
                self._by_format.setdefault(format_id, position)
            if source.pattern is None:
                continue
            pattern = re.compile(source.pattern.pattern.encode("utf-8"))
            module = (
                re.compile(source.module_pattern.pattern.encode("utf-8")) if source.module_pattern is not None else None
            )
            self._sources.append((position, pattern, module, source))

        if len(rules.noise) > MAX_NOISE_FAMILIES:
            raise ValueError(f"{len(rules.noise)} familles de bruit : le masque en accepte {MAX_NOISE_FAMILIES}")
        self.noise_order = [family.id for family in rules.noise]
        familles = [
            (1 << bit, re.compile(family.pattern.pattern.encode("utf-8")), family.on_message, family.formats)
            for bit, family in enumerate(rules.noise)
        ]
        # Familles a essayer pour chaque format, calculees une fois : une famille
        # propre a DCSServerBot n'a rien a trouver dans un dcs.log, et ses motifs
        # a alternatives y couteraient une recherche par ligne.
        self._noise_by_format: dict[int, list[tuple[int, re.Pattern[bytes], bool]]] = {
            position: [
                (bit, pattern, on_message)
                for bit, pattern, on_message, formats in familles
                if not formats or (position != NO_FORMAT and FORMATS[position].id in formats)
            ]
            for position in (*range(len(FORMATS)), NO_FORMAT)
        }
        self._noise_cache: dict[int, tuple[str, ...]] = {0: ()}

    # -- classement -------------------------------------------------------

    def header(self, line: bytes) -> tuple[int, re.Match[bytes] | None]:
        """Reconnait la forme d'en-tete d'une ligne.

        Args:
            line: La ligne, sans sa fin de ligne.

        Returns:
            L'index du format dans `FORMATS` et sa correspondance, ou
            `(NO_FORMAT, None)` quand aucun format ne reconnait la ligne.
        """
        for position, pattern in enumerate(self._headers):
            match = pattern.match(line)
            if match is not None:
                return position, match
        return NO_FORMAT, None

    def format_source(self, format_id: str) -> int:
        """Donne la source emettrice des lignes d'un format.

        Args:
            format_id: Identifiant du format (`HeaderFormat.id`).

        Returns:
            L'index de la source qui declare ce format dans `formats`, la source
            native a defaut.
        """
        return self._by_format.get(format_id, self.native_source)

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

    @staticmethod
    def level_id(fmt: HeaderFormat, level: bytes | None) -> int:
        """Traduit le niveau ecrit dans une ligne en index de `LEVELS`.

        Args:
            fmt: Le format de la ligne, qui porte sa table de niveaux.
            level: Le niveau tel qu'ecrit, ou None quand le format n'en ecrit pas.

        Returns:
            L'index du niveau, `UNKNOWN` pour un niveau que la table ignore.
        """
        if not level:
            return LEVEL_INDEX.get(fmt.default_level, UNKNOWN_LEVEL)
        name = level.decode("ascii", "replace")
        return LEVEL_INDEX.get(fmt.level_map.get(name, name), UNKNOWN_LEVEL)

    def noise_mask(self, line: bytes, message: bytes, found: int) -> int:
        """Calcule les familles de bruit qui correspondent a une ligne.

        Args:
            line: La ligne entiere.
            message: Son message seul, pour les familles `on_message`.
            found: L'index de son format, qui borne les familles essayees.

        Returns:
            Le masque binaire des familles qui correspondent.
        """
        mask = 0
        for bit, pattern, on_message in self._noise_by_format[found]:
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

    def stamp_of(self, found: int, raw: str) -> tuple[str, str]:
        """Releve l'horodatage et le sous-systeme d'une ligne d'en-tete.

        Args:
            found: L'index du format de la ligne, ou `NO_FORMAT`.
            raw: La ligne decodee.

        Returns:
            L'horodatage sous la forme « AAAA-MM-JJ HH:MM:SS.mmm » (vide quand la
            ligne n'en porte pas) et le sous-systeme (vide s'il n'y en a pas).
        """
        match = self._headers_text[found].match(raw) if found != NO_FORMAT else None
        if match is None:
            # Une ligne qui commence par une date garde son heure meme quand son
            # en-tete s'ecarte des formats connus.
            return (raw[:23] if raw[:4].isdigit() and raw[4:5] == "-" else ""), ""
        groups = match.groupdict()
        time = (groups.get("time") or "").replace(",", ".")
        date = groups.get("date")
        return (f"{date} {time}" if date else time), groups.get("subsystem") or ""
