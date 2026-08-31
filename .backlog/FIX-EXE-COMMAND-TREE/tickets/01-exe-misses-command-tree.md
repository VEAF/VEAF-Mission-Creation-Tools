# 01 — The exe never builds the command tree

Status: ⬜ ready

Type: fix · Files: `src/python/veaf-tools/veaf-tools.py`, `src/python/veaf-tools/veaf_tools/app.py`

## Reproduce

```bash
poetry run veaf-tools content extract-aircraft-groups --help   # works
```

Then build the exe (or take a released one) and run the same: the subcommand does not exist, and
`--help` shows the flat list.

`grep -rn 'build_cli_tree' src/` returns three hits: the definition, and one call in `app.py`.

## Definition of done

- [ ] The exe exposes the tree
- [ ] One test asserts the two entry points expose the **same command set** — walk the Typer app
      each one produces and compare. A test that only checks `content` exists would pass again the
      day a new group is added to one side only
- [ ] Flat aliases still resolve from both entry points
- [ ] `doc/CLI_REFERENCE` needs no change if the fix works — but re-read it and fix anything it
      promises that still does not hold
