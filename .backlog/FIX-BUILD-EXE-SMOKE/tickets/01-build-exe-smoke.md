# 01 — collect-submodules sees the source tree, and every built executable is started once

Status: 🔄 in-progress

## Done when

- A build run outside Poetry produces a `veaf-tools` executable that starts (measured before and after).
- A build whose executable does not start exits non-zero, with the executable's error in the message (measured on the reproduced case).
- Unit tests cover the `PYTHONPATH` wiring and the smoke run: a failing, a timing-out and a missing executable each abort the build.
