# FIX-LOGS-SEARCH-REDACTION — the search typed by the user goes to the Worker redacted

Status: ✅ done

Origin: an automated security review of the Go port's J5 (#1183), 2026-10-24, confirmed on the shipped Python `veaf-logs`; David asked to fix the Python too.

The excerpt's header repeats the active search criteria as the user typed them (`recherche : Texte : …`), and *Analyser en ligne* sends that header to the VEAF Worker as it stands.
Every record of the excerpt is redacted, the header's searches were not: an address, a path or a name typed in the search field left the machine in clear.
The `/bug` report block was not affected: it is redacted whole.

## Decisions

- The searches are redacted where the header is built (`build_excerpt`), like the records, rather than at the network boundary: the header is also what the dialog shows, and it should show what leaves.
- The Go port does the same since #1183.

## Tickets

- [01 — Redact the searches of the excerpt's header](tickets/01-redact-header-searches.md)
