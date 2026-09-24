# 01 — `servers` block in the user config

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: feat
Files: `src/python/veaf-tools/veaf_libs/user_config.py`, `test/python/test_user_config.py`

## What

Read and validate a `servers:` mapping from `~/veafmct.yaml`: per server `host` (required),
`user` (required), `port` (default 22), `key` (optional path, `~` expanded), `logs` (mapping
instance name → remote path, at least one). Expose `get_servers()` returning typed objects.

## Done when

- A valid block parses; a missing `host`, an empty `logs`, a non-mapping value raise a readable
  `ValueError` naming the server.
- No `servers` block → empty list, no error.
