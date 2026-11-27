# FIX-MCP-LIST-CATALOG-COMPACT-CAP — `list_catalog` exceeds the compact response cap

Status: ⬜ ready

Found by the session of FIX-MCP-REPLAY-FINDINGS on 2026-11-27, already true on `develop` before that lot: in the compact profile `list_catalog` answers 7 921 characters with the response cut, because the raw list of the 77 actions is 8 228 characters and the cap is 8 000. A model with a 65 536-token context then sees a truncated catalogue.
David, 2026-11-27 (relayed by the local-model test session): its own ticket, outside the PR of FIX-MCP-REPLAY-FINDINGS, and not implemented before his go.

One ticket.
