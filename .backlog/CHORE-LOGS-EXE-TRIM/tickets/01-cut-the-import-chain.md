# 01 — cut the import chain, or exclude the packages

Status: ⬜ ready
Type: chore
Files: `veaf-logs.spec`, possibly `src/python/veaf-tools/veaf_libs/diagnostics.py`,
`src/python/veaf-tools/veaf_logs/report.py`

## What

1. Confirm the chain with `build/veaf-logs/xref-veaf-logs.html` (who imports `mcp`, `mypy`,
   `uvicorn`) or `python -X importtime -c "import veaf_logs.ui.main_window"` for the runtime side.
2. Prefer cutting the edge if it is a delayed or optional import in `veaf_libs.diagnostics`
   (the viewer only needs `BLOCK_START`, `BLOCK_END` and `DiagnosticReport`); otherwise add the
   top-level packages to the `excludes` list of `veaf-logs.spec`, next to the unused Qt modules,
   each with the one-line reason the recipe already gives for the others.
3. Rebuild, measure size and cold start, run `pyi-archive_viewer -l` to prove the packages are gone,
   and open a local and a remote log with the built exe.

## Done when

The PRD's definition of done holds and the numbers are written in the PRD.
