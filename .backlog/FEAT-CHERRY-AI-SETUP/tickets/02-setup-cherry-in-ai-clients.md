# 02 — `setup_cherry` in `ai_clients.py`

Status: ⬜ ready (waits for the verdict of ticket 01)
Type: feature
Files: `src/python/veaf-tools/veaf_libs/ai_clients.py`, `test/python/veaf_libs/test_ai_clients.py` (or the file that covers the other clients)

Add `setup_cherry(...)` and its entry in `setup_all`, with the guarantees of the other clients: idempotent, existing configuration kept, result `not_found` when Cherry is absent.
The MCP command carries `VEAF_MCP_PROFILE=compact`.
Never write into the database of a running application without a guard: refuse, with a clear message, when Cherry is open or when its version is not one the study checked.
Tests: absent → `not_found`; run twice → unchanged; other servers and settings kept; refusal when Cherry is open; refusal on an unchecked version.
