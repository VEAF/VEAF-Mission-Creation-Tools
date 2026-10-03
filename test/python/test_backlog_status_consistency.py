"""A lot's status is written in three places; they must agree.

An index carries one entry per lot, `<LOT>/PRD.md` carries a `Status:` header and often a
scope table with one row per ticket, and each `tickets/NN-*.md` carries its own `Status:` header.
Nothing checked that the three tell the same story, and on 2026-08-10 that cost four separate
corrections in one day — the last of them inside the very commit that called the pattern out and
still left the index row on ⬜.

The rule is **agreement, not conformity**. Six of the 23 active lots deliberately shape their PRD
table differently (one has a *depends on* last column, not a status); this compares the sources that
exist rather than imposing one shape.

Two holes, closed after review: nothing may **silently opt out** of a check. A missing `Status:`
line and an unrecognised icon both used to make a file or a row invisible, which is the failure mode
this gate exists to remove — the same one that let a coverage rule pass while extracting zero names
and a link checker compensate for a defect instead of reporting it.

Since CHORE-BACKLOG-INDEX-SPLIT (2026-10-03) the index is three files — `ACTIVE.md`, `READY.md`,
`DONE.md` — and `README.md` is a front page listing them. That adds two ways to be wrong, both checked
here: a lot filed in the index of another status (closed, and never moved to `DONE.md`), and a front
page whose counts or lists no longer match the indexes.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

BACKLOG = Path(__file__).parents[2] / ".backlog"

#: The single `Status:` vocabulary, from `docs/agents/triage-labels.md`.
STATUS_ICONS = "⬜🔄🧑⏸✅🚫"
_ICON = re.compile(f"[{STATUS_ICONS}]")

#: `### [LOT-ID](LOT-ID/PRD.md) · ✅` — the heading of a lot's paragraph in an index.
_INDEX_ENTRY = re.compile(r"^### \[([A-Z0-9-]+)\]\([^)]*\) · (.*)$")

#: Which statuses each index holds. Archived lots are files under `archive/`, in its own README.
INDEXES = {"ACTIVE.md": "🔄🧑⏸", "READY.md": "⬜", "DONE.md": "✅🚫"}

#: `## [Active lots](ACTIVE.md) — 25`, the front page's heading for one index.
_FRONT_HEADING = re.compile(r"^## \[[^\]]+\]\(([A-Z]+\.md)\) — (\d+)$")
#: `- **🧑 Waiting for a human (21)** — [LOT](LOT/PRD.md) · …`, one line per status.
_FRONT_LINE = re.compile(r"^- \*\*(\S+) [^(]+\((\d+)\)\*\* — (.*)$")
_LOT_LINK = re.compile(r"\[([A-Z0-9-]+)\]\(\1/PRD\.md\)")

#: A data row of a scope table: its first cell is the ticket number.
_TICKET_ROW = re.compile(r"^\|\s*(\d{2})\s*\|")

#: A markdown table separator, e.g. `|---|:--:|---|`.
_SEPARATOR = re.compile(r"^\|[\s:|-]+\|$")


def _cells(line: str) -> list[str]:
    """Split a markdown table row into its trimmed cells."""
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def _sole_icon(text: str) -> str | None:
    """Return the status icon *text* consists of, or None when it is anything else.

    Deliberately strict: a cell holding an icon **plus** other words is not a status cell, and a cell
    holding an unknown glyph is a typo rather than something to skip.
    """
    found = _ICON.findall(text)
    if len(found) != 1 or _ICON.sub("", text).strip():
        return None
    return found[0]


def _header_status(path: Path) -> str | None:
    """Return the icon on a file's first `Status:` line, or None when it has none.

    The whole file is scanned, not a window at the top: a header further down used to read as
    *absent*, which skipped every comparison for that file instead of failing.
    """
    for line in path.read_text(encoding="utf-8").split("\n"):
        if line.startswith("Status:"):
            found = _ICON.search(line)
            return found.group(0) if found else None
    return None


def _index_entries() -> list[tuple[str, str, str | None]]:
    """Return `(index file, lot, status icon)` for every lot heading of the three indexes."""
    entries = []
    for name in INDEXES:
        for line in (BACKLOG / name).read_text(encoding="utf-8").split("\n"):
            match = _INDEX_ENTRY.match(line)
            if match:
                entries.append((name, match.group(1), _sole_icon(match.group(2))))
    return entries


def _index_statuses() -> dict[str, str | None]:
    """Return the status icon each lot carries in the indexes."""
    return {lot: icon for _, lot, icon in _index_entries()}


def _front_page() -> dict[str, tuple[int, dict[str, tuple[int, list[str]]]]]:
    """Return, per index file, the front page's total and `{icon: (stated count, listed lots)}`."""
    result: dict[str, tuple[int, dict[str, tuple[int, list[str]]]]] = {}
    current: str | None = None
    for line in (BACKLOG / "README.md").read_text(encoding="utf-8").split("\n"):
        heading = _FRONT_HEADING.match(line)
        if heading:
            current = heading.group(1)
            result[current] = (int(heading.group(2)), {})
            continue
        status = _FRONT_LINE.match(line)
        if status and current in result:
            result[current][1][status.group(1)] = (int(status.group(2)), _LOT_LINK.findall(status.group(3)))
    return result


def _active_lots() -> list[Path]:
    """Every active lot directory (archived lots are single files under `archive/`)."""
    return sorted(p for p in BACKLOG.iterdir() if p.is_dir() and p.name != "archive")


def _status_column(lines: list[str]) -> int | None:
    """Return the index of the column a PRD table names `Status`, or None when it has no such table.

    Keying on the **header** rather than on "the last cell" is what makes this reliable:
    `FEAT-ASSIST-AUTHORING` and `FEAT-ASSIST-CHECKLISTS` end their table with a *depends on* column
    holding values like `01, 02` or `—`, which a positional rule reads as a broken status.
    """
    header = _status_header_line(lines)
    if header is None:
        return None
    cells = _cells(lines[header])
    return cells.index(next(c for c in cells if c.lower() == "status"))


def _status_header_line(lines: list[str]) -> int | None:
    """Return the line index of the header row naming a `Status` column, or None."""
    for index, line in enumerate(lines):
        if not line.startswith("|") or _SEPARATOR.match(line):
            continue
        if any(cell.lower() == "status" for cell in _cells(line)):
            return index
    return None


def _table_block(lines: list[str], header: int) -> list[str]:
    """Return the contiguous table rows following the header at *header*.

    Scoping to one table matters because a PRD may hold **several** tables whose first cell is a
    two-digit number. `FEAT-MCP-MUTATION-ACTIONS` has one: its triage table maps ticket numbers to
    actions, and reading those rows at the scope table's `Status` column yielded prose instead of an
    icon — then overwrote the real rows, since a later row wins in the dict. The gate reported the
    scope table as broken when the scope table was fine.
    """
    block: list[str] = []
    for line in lines[header + 1 :]:
        if not line.startswith("|"):
            break
        block.append(line)
    return block


def _scope_rows(prd: Path) -> dict[str, str | None]:
    """Return `{ticket number: status icon}` from the PRD's scope table.

    Empty when the PRD has no table naming a `Status` column. A cell whose content is not exactly one
    known icon maps to ``None`` so it is **reported**, not skipped.
    """
    lines = prd.read_text(encoding="utf-8").split("\n")
    header = _status_header_line(lines)
    column = _status_column(lines)
    if header is None or column is None:
        return {}
    rows: dict[str, str | None] = {}
    # Only this table's rows: another table further down may also start its rows with a two-digit
    # number, and reading those at this column reports the wrong thing about the right table.
    for line in _table_block(lines, header):
        match = _TICKET_ROW.match(line)
        if not match:
            continue
        cells = _cells(line)
        rows[match.group(1)] = _sole_icon(cells[column]) if column < len(cells) else None
    return rows


class TestEveryLotIsListed(unittest.TestCase):
    def test_each_active_lot_has_an_index_entry(self) -> None:
        listed = set(_index_statuses())
        missing = sorted(lot.name for lot in _active_lots() if lot.name not in listed)
        self.assertEqual(missing, [], f"lots in no index (ACTIVE.md, READY.md, DONE.md): {missing}")

    def test_each_lot_is_listed_once(self) -> None:
        seen: dict[str, list[str]] = {}
        for name, lot, _ in _index_entries():
            seen.setdefault(lot, []).append(name)
        twice = {lot: names for lot, names in seen.items() if len(names) > 1}
        self.assertEqual(twice, {}, f"lots listed more than once: {twice}")

    def test_each_index_entry_has_a_lot_directory(self) -> None:
        on_disk = {lot.name for lot in _active_lots()}
        dangling = sorted(lot for _, lot, _ in _index_entries() if lot not in on_disk)
        self.assertEqual(dangling, [], f"index entries with no `.backlog/<LOT>/` (archived? renamed?): {dangling}")

    def test_each_lot_sits_in_the_index_of_its_status(self) -> None:
        """A lot closed and never moved to DONE.md, or picked up and left in READY.md, is filed wrong."""
        misfiled = []
        for name, lot, _ in _index_entries():
            prd = BACKLOG / lot / "PRD.md"
            status = _header_status(prd) if prd.exists() else None
            if status is not None and status not in INDEXES[name]:
                expected = next(index for index, icons in INDEXES.items() if status in icons)
                misfiled.append(f"{lot} is {status} but listed in {name}, belongs in {expected}")
        self.assertEqual(misfiled, [], "\n  ".join(misfiled))


class TestTheFrontPageAgreesWithTheIndexes(unittest.TestCase):
    """`README.md` restates each index as a count and a list; both go stale without a check."""

    def test_every_index_has_a_front_page_section(self) -> None:
        self.assertEqual(sorted(_front_page()), sorted(INDEXES))

    def test_the_front_page_lists_exactly_the_lots_of_each_status(self) -> None:
        by_status: dict[str, list[str]] = {}
        for _, lot, icon in _index_entries():
            by_status.setdefault(icon or "?", []).append(lot)
        drift = []
        for name, (total, lines) in _front_page().items():
            for icon in INDEXES[name]:
                stated, listed = lines.get(icon, (-1, []))
                actual = sorted(by_status.get(icon, []))
                if sorted(listed) != actual:
                    drift.append(f"{name} {icon}: front page lists {sorted(listed)}, index has {actual}")
                if stated != len(actual):
                    drift.append(f"{name} {icon}: front page says {stated}, index has {len(actual)}")
            expected_total = sum(len(by_status.get(icon, [])) for icon in INDEXES[name])
            if total != expected_total:
                drift.append(f"{name}: front page total {total}, index has {expected_total}")
        self.assertEqual(drift, [], "README.md disagrees with the indexes:\n  " + "\n  ".join(drift))

    def test_each_active_lot_has_a_prd(self) -> None:
        missing = sorted(lot.name for lot in _active_lots() if not (lot / "PRD.md").exists())
        self.assertEqual(missing, [], f"lot directories with no PRD.md: {missing}")


class TestNothingOptsOutSilently(unittest.TestCase):
    """A file or row with no readable status must fail, not disappear from the comparisons."""

    def test_every_prd_and_ticket_declares_a_known_status(self) -> None:
        offenders = []
        for lot in _active_lots():
            paths = [lot / "PRD.md"]
            if (lot / "tickets").is_dir():
                paths += sorted((lot / "tickets").glob("*.md"))
            for path in paths:
                if not path.exists():
                    continue
                if _header_status(path) is None:
                    offenders.append(path.relative_to(BACKLOG).as_posix())
        self.assertEqual(
            offenders,
            [],
            "no `Status:` line, or one carrying no known icon — these escape every check below:\n  "
            + "\n  ".join(offenders),
        )

    def test_every_index_entry_declares_a_known_status(self) -> None:
        offenders = sorted(lot for lot, icon in _index_statuses().items() if icon is None)
        self.assertEqual(offenders, [], f"index headings whose status is not a lone known icon: {offenders}")

    def test_every_scope_row_declares_a_known_status(self) -> None:
        offenders = []
        for lot in _active_lots():
            prd = lot / "PRD.md"
            if not prd.exists():
                continue
            for number, icon in _scope_rows(prd).items():
                if icon is None:
                    offenders.append(f"{lot.name} row {number}")
        self.assertEqual(offenders, [], f"scope rows whose Status cell is not a lone known icon: {offenders}")


class TestTheIndexAgreesWithThePrd(unittest.TestCase):
    def test_the_row_and_the_prd_header_carry_the_same_status(self) -> None:
        index = _index_statuses()
        drift = []
        for lot in _active_lots():
            prd = lot / "PRD.md"
            if not prd.exists():
                continue
            row, header = index.get(lot.name), _header_status(prd)
            if row != header:
                drift.append(f"{lot.name}: index entry {row} vs PRD header {header}")
        self.assertEqual(drift, [], "the index and the PRD disagree:\n  " + "\n  ".join(drift))


class TestThePrdAgreesWithItsTickets(unittest.TestCase):
    """Where a PRD lists a ticket, its status must be the one the ticket itself declares.

    The ticket file is the one someone edits on finishing the work, so it is the source that drifts
    *last* — which is why the scope table is the half that goes stale.
    """

    def test_every_scope_row_matches_its_ticket(self) -> None:
        drift = []
        for lot in _active_lots():
            prd, tickets = lot / "PRD.md", lot / "tickets"
            if not prd.exists() or not tickets.is_dir():
                continue
            rows = _scope_rows(prd)
            for ticket in sorted(tickets.glob("*.md")):
                number = ticket.name[:2]
                if number not in rows:
                    continue  # a PRD with no Status column, or a ticket it does not list
                if _header_status(ticket) != rows[number]:
                    drift.append(f"{lot.name}/{ticket.name}: PRD row {rows[number]} vs ticket {_header_status(ticket)}")
        self.assertEqual(drift, [], "a PRD scope table is stale:\n  " + "\n  ".join(drift))

    def test_a_done_lot_has_no_ticket_still_open(self) -> None:
        """A lot cannot be finished while a ticket of its own says it is not started.

        The gap this closes, found by a reviewer rather than by this file on 2026-08-23: three lots were
        marked ✅ with every definition-of-done box unticked, and one of them had two tickets still on ⬜.
        Everything above passed, because each check compared a *pair* that happened to agree — the index
        matched the PRD header, and the scope table matched the tickets. Nobody compared the header with
        the tickets, so the whole lot could be consistent and wrong.

        `🚫 wontfix` and `⏸ paused` tickets are fine under a done lot: work can legitimately be dropped
        or parked while the rest ships. `⬜ ready` and `🔄 in-progress` cannot.
        """
        unfinished = {"⬜", "🔄"}
        drift = []
        for lot in _active_lots():
            prd, tickets = lot / "PRD.md", lot / "tickets"
            if not prd.exists() or _header_status(prd) != "✅" or not tickets.is_dir():
                continue
            for ticket in sorted(tickets.glob("*.md")):
                status = _header_status(ticket)
                if status in unfinished:
                    drift.append(f"{lot.name} is ✅ but {ticket.name} is {status}")
        self.assertEqual(drift, [], "a done lot still has open tickets:\n  " + "\n  ".join(drift))

    def test_a_scope_row_names_a_ticket_that_exists(self) -> None:
        dangling = []
        for lot in _active_lots():
            prd, tickets = lot / "PRD.md", lot / "tickets"
            if not prd.exists():
                continue
            present = {t.name[:2] for t in tickets.glob("*.md")} if tickets.is_dir() else set()
            for number in _scope_rows(prd):
                if number not in present:
                    dangling.append(f"{lot.name}: scope row {number} has no ticket file")
        self.assertEqual(dangling, [], "\n  ".join(dangling))


if __name__ == "__main__":
    unittest.main()
