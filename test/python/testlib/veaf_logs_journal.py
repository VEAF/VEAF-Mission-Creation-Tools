"""Journal de reference partage par les tests de veaf-logs.

Les helpers communs vivent dans `testlib` plutot que dans un `conftest` :
avec `--import-mode=importlib`, un module de test ne peut pas importer un
fichier voisin, alors que `testlib` est sur le `pythonpath`.
"""

from __future__ import annotations

# Une erreur ED connue, deux lignes VEAF dont un avertissement masque sous un
# INFO de DCS, une ligne CTLD, une erreur de script suivie de sa trace de pile,
# et un avertissement ED bavard.
JOURNAL = [
    "2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.",
    "2026-08-31 11:50:41.000 INFO    SCRIPTING (Main): VEAF|I|5390: Loading version 6.16.5",
    "2026-08-31 11:50:42.000 INFO    SCRIPTING (Main): VEAF|W|log|123: zone introuvable",
    "2026-08-31 11:50:43.000 INFO    SCRIPTING (Main): [CTLD][INFO] scene registered",
    "2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error: CSAR.lua:2213",
    "stack traceback:",
    "\t[C]: in function 'getUnitRecordById'",
    "2026-08-31 11:55:10.095 WARNING FLIGHT (Main): No taxiroad found on Batumi from 1 to 2",
]

# Six entrees : les deux lignes de trace rejoignent l'erreur de script.
ENTRIES = 6


def journal_bytes() -> bytes:
    return ("\n".join(JOURNAL) + "\n").encode("utf-8")
