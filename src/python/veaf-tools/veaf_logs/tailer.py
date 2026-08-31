"""Ouverture d'un journal et detection de sa rotation.

DCS ne tronque pas son journal en cours de route ; il le renomme en `.old` au
lancement suivant et repart d'un fichier neuf. Cette classe fournit le `Buffer`
d'ou l'index lit ses octets, et signale les cas ou il faut tout reprendre :
fichier remplace, tronque, ou reecrit sans changer de taille.
"""

from __future__ import annotations

import os
import zipfile
from dataclasses import dataclass
from pathlib import Path

from .buffer import Buffer, BytesBuffer, FileBuffer

# Les archives produites par DCS contiennent aussi le vidage memoire, la mission
# et le rapport dxdiag. On ne veut que le journal.
_ARCHIVE_LOG_SUFFIXES = (".log", ".txt")
_ARCHIVE_PREFERRED = ("dcs.", "dcs-")

# Empreinte de debut de fichier, relue a chaque passage pour reperer une
# rotation qui n'aurait change ni la taille ni l'identite du fichier.
_HEAD_BYTES = 512


class LogUnavailable(OSError):
    """Le fichier a suivre est momentanement absent (rotation en cours)."""


@dataclass(slots=True)
class FileIdentity:
    """De quoi detecter qu'on ne lit plus le meme fichier.

    Volontairement reduit au couple inode / peripherique, l'identite canonique
    d'un fichier. On a d'abord ajoute `st_ctime` en pensant y gagner de la
    robustesse : sous Windows c'est la date de creation, qui ne bouge jamais.
    Sous Linux, c'est l'heure du dernier changement d'inode, donc **chaque
    ecriture la modifie** — un journal qui grossit passait alors pour un
    fichier neuf, et etait relu du debut a chaque ligne ajoutee.

    Reste le cas ou `st_ino` vaut 0, ce qui arrive sur certains systemes de
    fichiers Windows : la comparaison ne distingue plus rien, et c'est
    l'empreinte de debut de fichier (`_head_changed`) qui prend le relais.
    """

    inode: int
    device: int

    @classmethod
    def of(cls, path: Path) -> FileIdentity:
        info = path.stat()
        return cls(inode=info.st_ino, device=info.st_dev)


def archive_members(path: Path) -> list[str]:
    """Journaux contenus dans une archive, le plus probable en tete."""
    with zipfile.ZipFile(path) as archive:
        names = [
            name
            for name in archive.namelist()
            if not name.endswith("/") and name.lower().endswith(_ARCHIVE_LOG_SUFFIXES)
        ]

    def rank(name: str) -> tuple[int, int]:
        base = os.path.basename(name).lower()
        # Un `dcs.<date>.log` passe avant `dxdiag.txt`.
        return (0 if base.endswith(".log") else 1, 0 if base.startswith(_ARCHIVE_PREFERRED) else 1)

    return sorted(names, key=rank)


class LogSource:
    """Un journal ouvert : son tampon d'octets et l'etat de sa rotation."""

    def __init__(self, path: Path | str, *, archive_member: str | None = None) -> None:
        self.path = Path(path)
        self.archive_member = archive_member
        self.is_archive = self.path.suffix.lower() == ".zip"
        self._identity: FileIdentity | None = None
        self._head = b""
        self._buffer: Buffer | None = None

    # -- ouverture --------------------------------------------------------

    def open(self) -> Buffer:
        """Cree le tampon. Leve `LogUnavailable` si le fichier a disparu."""
        if self.is_archive:
            self._buffer = BytesBuffer(self._read_archive())
            return self._buffer
        if not self.path.exists():
            raise LogUnavailable(str(self.path))
        self._buffer = FileBuffer(self.path)
        self._identity = FileIdentity.of(self.path)
        self._head = self._read_head()
        return self._buffer

    def _read_archive(self) -> bytes:
        members = archive_members(self.path)
        if not members:
            raise LogUnavailable(f"aucun journal dans l'archive {self.path.name}")
        self.archive_member = self.archive_member or members[0]
        with zipfile.ZipFile(self.path) as archive:
            return archive.read(self.archive_member)

    @property
    def buffer(self) -> Buffer:
        if self._buffer is None:
            return self.open()
        return self._buffer

    def close(self) -> None:
        if self._buffer is not None:
            self._buffer.close()
            self._buffer = None

    # -- etat -------------------------------------------------------------

    @property
    def display_name(self) -> str:
        if self.is_archive and self.archive_member:
            return f"{self.path.name} : {os.path.basename(self.archive_member)}"
        return self.path.name

    @property
    def followable(self) -> bool:
        """Une archive est un instantane : rien n'y sera ajoute."""
        return not self.is_archive

    def check_rotation(self, indexed: int) -> bool:
        """Le fichier a-t-il ete remplace depuis ? Leve `LogUnavailable` s'il manque.

        `indexed` est le nombre d'octets deja pris en compte : un fichier plus
        court que cela a forcement ete reecrit.
        """
        if self.is_archive:
            return False
        try:
            identity = FileIdentity.of(self.path)
            size = self.path.stat().st_size
            head = self._read_head()
        except FileNotFoundError as exc:
            # DCS est en train de faire tourner le fichier : on patiente sans
            # rien perdre, la lecture reprendra au passage suivant.
            raise LogUnavailable(str(self.path)) from exc

        rotated = identity != self._identity or size < indexed or self._head_changed(head)
        self._identity = identity
        self._head = head
        return rotated

    def reopen(self) -> Buffer:
        """Repart de zero apres une rotation."""
        self.close()
        return self.open()

    # -- interne ----------------------------------------------------------

    def _read_head(self) -> bytes:
        with open(self.path, "rb") as handle:
            return handle.read(_HEAD_BYTES)

    def _head_changed(self, head: bytes) -> bool:
        """Le debut du fichier a-t-il ete reecrit ?

        La comparaison porte sur la longueur commune : tant que le journal fait
        moins de `_HEAD_BYTES`, l'empreinte s'allonge a chaque ecriture sans que
        rien n'ait ete reecrit.
        """
        common = min(len(head), len(self._head))
        return head[:common] != self._head[:common]
