"""La fenetre d'analyse : le catalogue tout de suite, le modele quand on le demande.

The catalogue layer costs nothing and needs no network, so it is computed and shown before the
dialog even appears. The online layer is opt-in, behind a button, and runs on its own thread: a
request can take tens of seconds, and a frozen window is indistinguishable from a crashed one.

Nothing leaves the machine until the *Analyser en ligne* button is pressed, and what leaves then is
the excerpt the user is looking at, already redacted and already bounded. *Préparer un rapport*
sends nothing at all: it fills the clipboard, and the user decides where to paste it.
"""

from __future__ import annotations

from PySide6.QtCore import QThread, Signal
from PySide6.QtWidgets import (
    QApplication,
    QDialog,
    QDialogButtonBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPlainTextEdit,
    QPushButton,
    QVBoxLayout,
)

from ..analysis import Analysis
from ..catalogue import WorkerMatch, to_worker_matches
from ..report import build_report, to_clipboard_text
from ..worker_client import AnalysisUnavailable, analyse_excerpt


class OnlineAnalysisThread(QThread):
    """Runs the Worker call off the interface thread."""

    answered = Signal(str)
    failed = Signal(str)

    def __init__(self, excerpt: str, matches: list[WorkerMatch], question: str, parent=None) -> None:
        """Prepare the request.

        Args:
            excerpt: The rendered, redacted excerpt.
            matches: The catalogue entries matched locally.
            question: The user's question, possibly empty.
            parent: Qt parent.
        """
        super().__init__(parent)
        self._excerpt = excerpt
        self._matches = matches
        self._question = question

    def run(self) -> None:
        """Post the request and emit whichever of the two signals applies."""
        try:
            self.answered.emit(analyse_excerpt(self._excerpt, self._matches, question=self._question))
        except AnalysisUnavailable as exc:
            self.failed.emit(str(exc))
        except Exception as exc:  # pragma: no cover - defensive: the network layer is third-party
            self.failed.emit(f"Analyse en ligne indisponible : {exc}")


class AnalysisDialog(QDialog):
    """Shows an analysis, and offers to enrich it online or to turn it into a report block."""

    def __init__(self, analysis: Analysis, parent=None) -> None:
        """Build the dialog around an already computed, offline analysis.

        Args:
            analysis: The catalogue-layer analysis to show.
            parent: Qt parent.
        """
        super().__init__(parent)
        self.analysis = analysis
        self._thread: OnlineAnalysisThread | None = None
        self.setWindowTitle("Analyse du journal")
        self.resize(1000, 700)

        self.text = QPlainTextEdit()
        self.text.setReadOnly(True)
        self.text.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.text.setPlainText(analysis.to_text())

        self.question = QLineEdit()
        self.question.setPlaceholderText("Question facultative pour l'analyse en ligne…")

        self.online_button = QPushButton("Analyser en ligne")
        self.online_button.setToolTip(
            "Envoie l'extrait caviardé et les motifs du catalogue au service VEAF. Rien d'autre ne part."
        )
        self.online_button.clicked.connect(self.run_online)

        self.report_button = QPushButton("Préparer un rapport")
        self.report_button.setToolTip("Copie un bloc collable dans /bug : diagnostic, extrait, catalogue, analyse.")
        self.report_button.clicked.connect(self.copy_report)

        self.status = QLabel("")

        top = QHBoxLayout()
        top.addWidget(self.question, 1)
        top.addWidget(self.online_button)
        top.addWidget(self.report_button)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
        buttons.rejected.connect(self.reject)

        layout = QVBoxLayout(self)
        layout.addLayout(top)
        layout.addWidget(self.text, 1)
        layout.addWidget(self.status)
        layout.addWidget(buttons)

    # -- online layer -----------------------------------------------------

    def run_online(self) -> None:
        """Start the Worker call, unless one is already running."""
        if self._thread is not None and self._thread.isRunning():
            return
        self.online_button.setEnabled(False)
        self.status.setText("Analyse en ligne en cours…")
        self._thread = OnlineAnalysisThread(
            self.analysis.excerpt.to_text(),
            to_worker_matches(self.analysis.matches),
            self.question.text().strip(),
            self,
        )
        self._thread.answered.connect(self.show_commentary)
        self._thread.failed.connect(self.show_failure)
        self._thread.start()

    def show_commentary(self, commentary: str) -> None:
        """Replace the model section with what the Worker answered."""
        self.analysis = _with_commentary(self.analysis, commentary.strip(), "")
        self.text.setPlainText(self.analysis.to_text())
        self.status.setText("Analyse en ligne reçue.")
        self.online_button.setEnabled(True)

    def show_failure(self, message: str) -> None:
        """State why the online layer produced nothing, without an error dialog.

        The catalogue answer above is still valid, and a modal box would suggest otherwise.
        """
        self.analysis = _with_commentary(self.analysis, "", message)
        self.text.setPlainText(self.analysis.to_text())
        self.status.setText(message)
        self.online_button.setEnabled(True)

    # -- report block -----------------------------------------------------

    def copy_report(self) -> None:
        """Assemble the report block and put it on the clipboard.

        The diagnostic half is collected here rather than at construction: it reads the tool's own
        log and probes the DCS install, which is work nobody should pay for by opening a window.
        A collection that fails costs the diagnostic section, never the report — the excerpt and the
        catalogue are the half the user came for.
        """
        block = build_report(self.analysis, _doctor_report())
        QApplication.clipboard().setText(to_clipboard_text(block))
        self.status.setText(f"Rapport copié ({len(block)} caractères). Colle-le dans /bug.")

    def closeEvent(self, event) -> None:
        """Wait for a running request rather than leaving a thread behind."""
        thread = self._thread
        if thread is not None and thread.isRunning():
            thread.wait(1000)
        super().closeEvent(event)


def _doctor_report():
    """Collect the ``veaf-tools doctor`` report, or ``None`` when it cannot be collected.

    Returns:
        The :class:`~veaf_libs.diagnostics.DiagnosticReport`, or ``None``. ``build_report`` accepts
        ``None`` and simply carries no diagnostic section, which is a smaller loss than a dialog
        that refuses to produce a report because it could not read a log file.
    """
    try:
        from veaf_libs.diagnostics import build_report as collect

        return collect()
    except Exception:  # pragma: no cover - defensive: collection touches the filesystem
        return None


def _with_commentary(analysis: Analysis, commentary: str, error: str) -> Analysis:
    """Return the same analysis carrying a different model section.

    :class:`~veaf_logs.analysis.Analysis` is frozen on purpose — it is the thing the report block is
    built from — so the online answer produces a new one instead of mutating the old.
    """
    return Analysis(
        excerpt=analysis.excerpt,
        matches=analysis.matches,
        uncatalogued=analysis.uncatalogued,
        uncatalogued_total=analysis.uncatalogued_total,
        proposals=analysis.proposals,
        commentary=commentary,
        model_error=error,
    )
