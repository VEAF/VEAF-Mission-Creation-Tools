# 02 — `^` and `$` bind to lines

Status: ✅ done

`filters._apply_text` runs the bytes pattern over `store.iter_blocks()` blocks without `re.MULTILINE`: `^` matches only the first entry of each 8 MB block, and `$` only before the block's final newline. Compile with `re.MULTILINE`; the Go engine (`internal/logcore/filters.go`) compiles with `(?m)` and drops `pythonDollar`; `testdata/gen_golden.py` is rerun so the goldens follow, and `go test ./...` stays green.

Found by the review: in multi-line mode, `^$` also matches the empty position past the block's final newline, which belongs to no line of the block and was brought back to the next entry (the last one on the test journal, which has no empty line). Both sides skip a match starting there; `^$` and `$` join the parity cases.
