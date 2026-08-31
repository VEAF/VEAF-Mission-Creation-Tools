"""Point d'entree : `python -m veaf_logs [fichier...]`."""

from __future__ import annotations

import sys

from veaf_logs.ui.main_window import run

if __name__ == "__main__":
    raise SystemExit(run(sys.argv))
