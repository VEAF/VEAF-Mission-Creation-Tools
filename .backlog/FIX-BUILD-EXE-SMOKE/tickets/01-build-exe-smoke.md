# 01 — collect-submodules sees the source tree, and every built executable is started once

Status: ✅ done

## Done when

- PyInstaller's `--collect-submodules mission_builder` finds the package whatever interpreter runs the build (measured: 0 → 19 modules outside Poetry).
- A build whose executable does not start exits non-zero, with the executable's error in the message (measured on the reproduced case).
- A build through `poetry run veaf-build` still exits 0, both executables starting.
- Unit tests cover the `PYTHONPATH` wiring and the smoke run: a failing, a timing-out and a missing executable each abort the build.
