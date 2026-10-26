# 09 — `read_mission_file` takes `path`

Status: ✅ done

Martinho's session: `read_mission_file` called with `path` failed with `missing required parameter(s) file; unknown parameter(s) path`, one turn lost; every other file action of the AI's tools reads a `path`-like word. The tool's own `edit`/`read` tools of the assistant use `path` too, so a model reaches for it first.

Fix: `read_mission_file` accepts `path` as an alias of `file` (and says in its schema that `file` is the name). Both given and different is refused naming both.

Done when: a test reads a file by `file`, by `path`, and refuses two different ones.

## Result

Fix: `ActionCatalog` reads `path` as `file` for an action that publishes `file` and no `path` (both given and different: refused). Tests in `test_catalog.py`.
