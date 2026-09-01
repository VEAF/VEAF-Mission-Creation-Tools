"""Acces aux octets d'un journal, sans le charger ni le verrouiller.

Deux contraintes se croisent ici.

La premiere est la taille : un journal de serveur peut depasser la centaine de
mega-octets, et le garder en memoire coute plusieurs fois sa taille. On ne lit
donc que les portions demandees.

La seconde a decide de l'implementation. Sous Windows, tant qu'un processus
garde un descripteur ouvert sur un fichier — projection memoire ou simple
`open()` — plus personne ne peut le renommer. Or c'est exactement ce que fait
DCS au lancement : il renomme `dcs.log` en `.old` avant d'en creer un neuf.
Un visualiseur qui garde le journal ouvert empecherait donc le jeu de demarrer
normalement. On ouvre et on referme a chaque lecture ; le surcout est de
quelques microsecondes, sans commune mesure avec le risque.
"""

from __future__ import annotations

from pathlib import Path


class Buffer:
    """Sequence d'octets adressable, dont la taille peut croitre."""

    def size(self) -> int:
        raise NotImplementedError

    def slice(self, start: int, length: int) -> bytes:
        raise NotImplementedError

    def refresh(self) -> int:
        """Reprend en compte ce qui a ete ecrit depuis. Rend la taille."""
        return self.size()

    def close(self) -> None:
        pass


class BytesBuffer(Buffer):
    """Contenu deja en memoire : archive extraite, ou test."""

    def __init__(self, data: bytes) -> None:
        self._data = data

    def size(self) -> int:
        return len(self._data)

    def slice(self, start: int, length: int) -> bytes:
        return self._data[start : start + length]


class FileBuffer(Buffer):
    """Fichier lu a la demande, jamais maintenu ouvert.

    Voir l'en-tete du module : conserver le descripteur empecherait DCS de
    faire tourner son journal.
    """

    def __init__(self, path: Path | str) -> None:
        self.path = Path(path)
        self._size = 0
        self.refresh()

    def size(self) -> int:
        return self._size

    def slice(self, start: int, length: int) -> bytes:
        if length <= 0:
            return b""
        try:
            with open(self.path, "rb") as handle:
                handle.seek(start)
                return handle.read(length)
        except OSError:
            # Le fichier vient de disparaitre : l'appelant le constatera au
            # prochain controle de rotation.
            return b""

    def refresh(self) -> int:
        try:
            self._size = self.path.stat().st_size
        except OSError:
            self._size = 0
        return self._size
