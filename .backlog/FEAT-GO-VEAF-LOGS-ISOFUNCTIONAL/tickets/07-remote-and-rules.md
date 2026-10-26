# 07 — J4: remote journals, their session restore, the Règles menu

Status: ✅ done — 2026-10-24

Milestone J4, asked by David on 2026-10-24 ("fais le J4").

## Scope

Inventory items:

- *Fichier › Ouvrir un journal distant…* (M3, Ctrl+Shift+O): the `server › instance` of the `servers:` block of `~/veafmct.yaml`, with the Python's boxes for an invalid configuration and for no server.
- The host key question (O3): a server absent from `known_hosts` is asked about, its key appended there on yes, refused on no; a known server whose key changed is refused without asking.
- The session's remote tabs (X2–X4): reopened after the window shows, one at a time, each at its place in the session's order, without taking the front from the tab looked at; failures in the status bar, a server that did not answer not tried again for its other instances; closing meanwhile keeps the tabs not reopened in the saved session; the local journal by default only once nothing was reopened.
- *Règles* (M19 F5, M20): reload the catalogue and index every open journal again; open `rules.json`.

## Done when

- `sshlog` asks about unknown host keys and writes `known_hosts`, tested against a real SSH server in the test.
- The restore's order and its messages live in `internal/logview` (`restore.go`), tested; `Doc.Reclassify` indexes again with a new catalogue, archives and interrupted indexings included.
- On screen, against a local SSH server: the question, yes and no, the tabs restored in order, the session saved back.
