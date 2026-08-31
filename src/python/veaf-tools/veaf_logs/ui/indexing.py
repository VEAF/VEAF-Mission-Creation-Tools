"""Indexation progressive d'un gros journal.

Indexer 119 Mo prend une huitaine de secondes. Fait d'un bloc, l'interface
gelerait tout ce temps ; on decoupe donc le travail en tranches courtes,
enchainees par la boucle d'evenements de Qt.

Le decoupage se fait volontairement **sur le fil de l'interface** plutot que
dans un `QThread`. Un fil separe qui remplirait l'index pendant que la vue le
lit exigerait de verrouiller chaque acces — et un modele Qt lu depuis un autre
fil que celui qui l'a cree est une source classique de plantages difficiles a
reproduire. Entre deux tranches, l'interface reprend la main : le resultat
percu est le meme, sans le risque.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, QTimer, Signal

# Duree visee pour une tranche. Assez courte pour que l'interface reste
# reactive, assez longue pour que le va-et-vient ne coute pas plus que le
# travail lui-meme.
SLICE_MS = 60

# Nombre d'octets traites par tranche, ajuste au fil de l'eau entre ces bornes.
MIN_CHUNK = 256 << 10
MAX_CHUNK = 16 << 20

# Traite d'emblee, sans passer par la boucle d'evenements : au-dela d'environ
# 4 Mo l'attente devient perceptible, en deca elle ne l'est pas.
UPFRONT_CHUNK = 4 << 20


class ProgressiveIndexer(QObject):
    """Indexe un journal par tranches, en rendant la main entre chacune."""

    progress = Signal(int, int)  # octets indexes, total
    batch_ready = Signal(int)  # entrees ajoutees par cette tranche
    finished = Signal()

    def __init__(self, store, parent=None) -> None:
        super().__init__(parent)
        self.store = store
        self._chunk = 1 << 20
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(0)
        self._timer.timeout.connect(self._step)
        self._running = False
        self._cancelled = False

    @property
    def running(self) -> bool:
        return self._running

    @property
    def total_bytes(self) -> int:
        return self.store.buffer.size()

    def start(self, upfront: int = UPFRONT_CHUNK) -> bool:
        """Demarre l'indexation. Rend True si elle se poursuit en tranches.

        Une premiere tranche genereuse est traitee tout de suite : la plupart
        des journaux DCS y tiennent entierement, et il serait desagreable de
        voir une barre de progression apparaitre et disparaitre pour un fichier
        traite en un clin d'oeil.
        """
        if self._running:
            return True
        self._cancelled = False

        added = self.store.index_new(max_bytes=upfront)
        if added:
            self.batch_ready.emit(added)
        if self.store.indexed_bytes >= self.total_bytes:
            self.progress.emit(self.store.indexed_bytes, self.total_bytes)
            self.finished.emit()
            return False

        self._running = True
        self.progress.emit(self.store.indexed_bytes, self.total_bytes)
        self._timer.start()
        return True

    def cancel(self) -> None:
        """Interrompt l'indexation. Ce qui est deja indexe reste utilisable."""
        self._cancelled = True

    def run_to_completion(self) -> int:
        """Indexe tout d'un trait. Pour les tests et les petits journaux."""
        added = 0
        while True:
            batch = self.store.index_new(max_bytes=MAX_CHUNK)
            if not batch:
                break
            added += batch
        return added

    # -- interne ----------------------------------------------------------

    def _step(self) -> None:
        if self._cancelled:
            self._running = False
            self.finished.emit()
            return

        from time import perf_counter

        started = perf_counter()
        added = self.store.index_new(max_bytes=self._chunk)
        elapsed = (perf_counter() - started) * 1000

        if added:
            self.batch_ready.emit(added)
        self.progress.emit(self.store.indexed_bytes, self.total_bytes)

        if self.store.indexed_bytes >= self.total_bytes or not added:
            self._running = False
            self.finished.emit()
            return

        # On vise `SLICE_MS` par tranche : si la derniere est allee vite, on
        # prend plus gros la prochaine fois, et inversement.
        if elapsed > 0:
            facteur = SLICE_MS / elapsed
            self._chunk = int(max(MIN_CHUNK, min(MAX_CHUNK, self._chunk * facteur)))
        self._timer.start()
