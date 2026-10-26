# 03 — Aliases, in the window and in the configuration

Status: ✅ done

- `servers.<server>.aliases.<log>` and a top-level `log_aliases.<path>` in `~/veafmct.yaml`.
- *Renommer l'onglet…* writes them, an empty name removes the alias, the rest of the file untouched (comments, order, other servers).
- Without an alias, an API's discovered logs lose the prefix all its servers share.

## Done when

- Tests: parsing the aliases; writing one into a file with comments and reading it back; removing one; a file created when there was none; the shared prefix cut only at a word boundary and only when every name keeps something.
