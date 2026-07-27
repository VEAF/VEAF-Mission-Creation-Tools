# Lot TODO0609-TUI-FOLDER-HINT — Clarify the TUI mission-folder default

Status: ✅ done

**Goal**: In the TUI, the mission-folder prompt shows a bare `.` default, which is not obviously the current directory. Add an explanatory label and show the resolved absolute path. Covers todo-2026.06.09 item 11.

**Branch**: `feat/tui-folder-hint` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUI-FOLDER-HINT-001 | Enrich the mission-folder prompt: explanatory label (`. = current folder`, FR/EN) and display the resolved absolute path as a hint. Update locales and tests. | `veaf_libs/tui.py`, locales, `test/python/` | feat | ✅ |
