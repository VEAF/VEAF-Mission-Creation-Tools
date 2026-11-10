# 01 — Aliases enforce the reached handler's level

Status: ⬜ ready

## Done when

- A non-bypassing alias whose command reaches a dispatcher-checked handler is refused below that handler's level, and passes at it (tests for `veafMove` and `veafRadio`, with and without the tier's password).
- A bypassing alias (`-smoke`, `-jtac`, `-tacan`, `-point`) still runs for everyone (test).
- Aliases reaching `veafSpawn` or `veafCasMission` behave as before (existing tests unchanged).
