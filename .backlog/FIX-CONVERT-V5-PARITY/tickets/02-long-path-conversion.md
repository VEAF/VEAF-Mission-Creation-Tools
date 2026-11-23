# 02 — A conversion that cannot finish writes nothing, and the build refuses it

Status: ⬜ ready

Issue: [#1301](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1301).

On a 149-character mission folder, `convert v5` copies the part into `backup_v5\`, dies on `[WinError 3]` at the deepest file (139 characters), after writing `mission.yaml` and before promoting `src/mission/`.
`mission build` then exits 0 on the half-converted folder.

- Before writing anything, compute the longest path the conversion will create (backup copy included). Past the Windows limit, either copy with the `\\?\` prefix, or refuse with a message naming the path and its length and suggesting a shorter folder. Pick the prefix if the copy and every later step accept it; otherwise refuse.
- Write `mission.yaml` last, so a conversion that fails leaves no v6 marker behind.
- Catch the failure: a clear error, exit 1, no Python traceback.

Tests: a fixture under a deep temporary folder (or a patched length limit) → the conversion refuses, or succeeds with the prefix; in the refusal case no `mission.yaml` is written and `mission build` on the folder fails.

Done when: the tests pass and Sharko's repro (149-character folder) either converts or refuses before writing.
