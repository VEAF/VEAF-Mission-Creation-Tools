"""A lot's status is written in three places; they must agree.

`.backlog/README.md` carries one row per lot, `<LOT>/PRD.md` carries a `Status:` header and often a
scope table with one row per ticket, and each `tickets/NN-*.md` carries its own `Status:` header.
Nothing checked that the three tell the same story, and on 2026-08-10 that cost four separate
corrections in one day — the last of them inside the very commit that called the pattern out and
still left the index row on ⬜.

The rule is **agreement, not conformity**. Several PRDs deliberately carry no scope table; this
compares the sources that exist rather than imposing one shape on every lot.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

BACKLOG = Path(__file__).parents[2] / ".backlog"

#: The single `Status:` vocabulary, from `docs/agents/triage-labels.md`.
STATUS_ICONS = "⬜🔄🧑⏸✅🚫"
_ICON = re.compile(f"[{STATUS_ICONS}]")

#: `| [LOT-ID](LOT-ID/PRD.md) — prose … | ✅ |`
_INDEX_ROW = re.compile(r"^\| \[([A-Z0-9-]+)\]\(")

#: `| 02 | [title](tickets/02-slug.md) | ✅ |` — the trailing cell is the status.
_SCOPE_ROW = re.compile(r"^\|\s*(\d{2})\s*\|.*\|\s*([" + STATUS_ICONS + r"])\s*\|\s*$")


def _first_icon(text: str) -> str | None:
    """Return the first status icon in *text*, or None."""
    found = _ICON.search(text)
    return found.group(0) if found else None


def _header_status(path: Path) -> str | None:
    """Return the icon on a PRD's or ticket's `Status:` line, or None when it has none."""
    for line in path.read_text(encoding="utf-8").split("\n")[:15]:
        if line.startswith("Status:"):
            return _first_icon(line)
    return None


def _index_statuses() -> dict[str, str | None]:
    """Return the status icon of every lot row in the backlog index."""
    result: dict[str, str | None] = {}
    for line in (BACKLOG / "README.md").read_text(encoding="utf-8").split("\n"):
        match = _INDEX_ROW.match(line)
        if not match:
            continue
        # The status is the last cell; the prose before it is free to contain icons of its own.
        cells = line.rstrip().rstrip("|").rsplit("|", 1)
        result[match.group(1)] = _first_icon(cells[-1]) if len(cells) > 1 else None
    return result


def _active_lots() -> list[Path]:
    """Every active lot directory (archived lots are single files under `archive/`)."""
    return sorted(p for p in BACKLOG.iterdir() if p.is_dir() and p.name != "archive")


def _scope_rows(prd: Path) -> dict[str, str]:
    """Return the PRD scope table's `{ticket number: status icon}`, empty when it has no table."""
    rows: dict[str, str] = {}
    for line in prd.read_text(encoding="utf-8").split("\n"):
        match = _SCOPE_ROW.match(line)
        if match:
            rows[match.group(1)] = match.group(2)
    return rows


class TestEveryLotIsListed(unittest.TestCase):
    def test_each_active_lot_has_an_index_row(self) -> None:
        listed = set(_index_statuses())
        missing = sorted(lot.name for lot in _active_lots() if lot.name not in listed)
        self.assertEqual(missing, [], f"lots with no row in .backlog/README.md: {missing}")

    def test_each_active_lot_has_a_prd(self) -> None:
        missing = sorted(lot.name for lot in _active_lots() if not (lot / "PRD.md").exists())
        self.assertEqual(missing, [], f"lot directories with no PRD.md: {missing}")


class TestTheIndexAgreesWithThePrd(unittest.TestCase):
    def test_the_row_and_the_prd_header_carry_the_same_status(self) -> None:
        index = _index_statuses()
        drift = []
        for lot in _active_lots():
            prd = lot / "PRD.md"
            if not prd.exists():
                continue
            row, header = index.get(lot.name), _header_status(prd)
            if row is not None and header is not None and row != header:
                drift.append(f"{lot.name}: index row {row} vs PRD header {header}")
        self.assertEqual(drift, [], "the index and the PRD disagree:\n  " + "\n  ".join(drift))


class TestThePrdAgreesWithItsTickets(unittest.TestCase):
    """Where a PRD lists a ticket, its status must be the one the ticket itself declares.

    The ticket file is the one someone edits on finishing the work, so it is the source that drifts
    *last* — which is why the scope table is the half that goes stale.
    """

    def test_every_scope_row_matches_its_ticket(self) -> None:
        drift = []
        for lot in _active_lots():
            prd = lot / "PRD.md"
            tickets = lot / "tickets"
            if not prd.exists() or not tickets.is_dir():
                continue
            rows = _scope_rows(prd)
            for ticket in sorted(tickets.glob("*.md")):
                number = ticket.name[:2]
                if number not in rows:
                    continue  # a PRD without a scope table, or a ticket it does not list
                declared = _header_status(ticket)
                if declared is not None and declared != rows[number]:
                    drift.append(f"{lot.name}/{ticket.name}: PRD row {rows[number]} vs ticket {declared}")
        self.assertEqual(drift, [], "a PRD scope table is stale:\n  " + "\n  ".join(drift))

    def test_a_scope_row_names_a_ticket_that_exists(self) -> None:
        dangling = []
        for lot in _active_lots():
            prd = lot / "PRD.md"
            tickets = lot / "tickets"
            if not prd.exists():
                continue
            present = {t.name[:2] for t in tickets.glob("*.md")} if tickets.is_dir() else set()
            for number in _scope_rows(prd):
                if number not in present:
                    dangling.append(f"{lot.name}: scope row {number} has no ticket file")
        self.assertEqual(dangling, [], "\n  ".join(dangling))


class TestTheVocabularyIsTheDocumentedOne(unittest.TestCase):
    def test_no_status_line_invents_an_icon(self) -> None:
        # `docs/agents/triage-labels.md` defines one vocabulary; a lot using anything else would slip
        # past every check above, which only ever compares icons it recognises.
        offenders = []
        for lot in _active_lots():
            for path in [lot / "PRD.md", *sorted((lot / "tickets").glob("*.md"))]:
                if not path.exists():
                    continue
                for line in path.read_text(encoding="utf-8").split("\n")[:15]:
                    if line.startswith("Status:") and _first_icon(line) is None:
                        offenders.append(f"{path.relative_to(BACKLOG).as_posix()}: {line[:60]}")
        self.assertEqual(offenders, [], "Status: lines with no known icon:\n  " + "\n  ".join(offenders))


if __name__ == "__main__":
    unittest.main()
