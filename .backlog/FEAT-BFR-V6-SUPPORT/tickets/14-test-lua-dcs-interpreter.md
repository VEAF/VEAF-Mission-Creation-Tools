# 14 — `test-lua` finds the Lua 5.1 shipped with DCS

Status: ⬜ ready

DCS ships a real Lua 5.1.5 as `<DCS install>\bin\luae.exe`; the runner only looked on PATH and in `C:\Program Files (x86)\Lua\5.1`.

## Done when

- On Windows, after the current candidates, the runner reads the DCS install path in the registry (`HKCU\Software\Eagle Dynamics\DCS World`, then `DCS World OpenBeta`, value `Path`) and tries `bin\luae.exe`, version-checked like any other candidate.
- The help message and `doc/TESTING.md` (FR + EN) say so, and say that `--coverage` still needs luacov on that interpreter's `package.path`.
- Python tests.
