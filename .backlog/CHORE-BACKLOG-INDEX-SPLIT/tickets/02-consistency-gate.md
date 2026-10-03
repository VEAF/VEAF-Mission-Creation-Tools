# 02 — the consistency gate reads the new indexes

Status: ✅ done — 2026-10-03
Type: chore

`test_backlog_status_consistency.py` parses the lot headings of the three indexes instead of the
README rows, and adds: a lot sits in exactly one index, the one its status belongs to; the front
page lists exactly the lots of each index, with the right count.
