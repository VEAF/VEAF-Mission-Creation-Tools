# 02 — `^` and `$` bind to lines

Status: ✅ done

`filters._apply_text` runs the bytes pattern over `store.iter_blocks()` blocks without `re.MULTILINE`: `^` matches only the first entry of each 8 MB block, and `$` only before the block's final newline. Compile with `re.MULTILINE`; the Go engine (`internal/logcore/filters.go`) compiles with `(?m)` and drops `pythonDollar`; `testdata/gen_golden.py` is rerun so the goldens follow, and `go test ./...` stays green.
