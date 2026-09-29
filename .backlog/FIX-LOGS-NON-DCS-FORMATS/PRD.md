# FIX-LOGS-NON-DCS-FORMATS — `veaf-logs` folds any non-DCS log into a single entry

Status: ✅ done — filed and fixed 2026-09-29

## Origin

David, 2026-09-29: *"veaf-logs n'affiche correctement que les logs DCS. Toute autre structure est
mal affichée"*, on `C:/Users/veaf/VEAF-DCSServerBot/logs/dcssb-dcs-veaf-org.log` over
`ssh:veaf@dcs.veaf.org`.

## Measured

`LogStore` over that file (4 104 lines): **one entry**, level `UNKNOWN`, 4 103 continuations.

The only header `parser.py` knows is DCS's, which carries the thread in brackets
(`... ERROR DX11BACKEND (20628): msg`). A line that does not match is taken for a continuation of
the previous entry — the mechanism that keeps a Lua stack trace with its error — so a file in any
other format collapses into its first line.

Formats found on dcs.veaf.org on 2026-09-29, one file of each fetched:

| Log | Line shape | Levels |
|---|---|---|
| DCSServerBot main, chat | `2026-09-29 18:09:52.446 DEBUG⇥msg` | DEBUG, INFO, WARNING, ERROR |
| DCSServerBot perf | `2026-09-29 18:03:38,541⇥INFO⇥msg` | INFO |
| Real Weather (own file, **and copied verbatim inside the DCSSB log**) | `2026-09-29T20:03:33.800+0200⇥INFO⇥msg` | INFO, WARN, ERROR, FATAL |
| LotAtc | `[2026-09-29 20:05:13 +02:00] [I] [clientserver] msg` | I, W |
| DCSSB `async_errors.log` | `=====` then `2026-05-26T00:47:56.023909: msg` + traceback | none |
| `sanctuary_zones-*.log` | `[]  INFO    SCRIPTING: msg` | INFO |
| `debrief.log` | a Lua table — not a log | — |

Because the DCSSB log interleaves two formats, detection is **per line**, not per file.

Content of the DCSSB log: 70 % (2 862 lines) are `onMissionEvent` bus messages, ~4 % periodic
polling (`getMissionUpdate`, `serverLoad`, `perfmon`, `registered with the cloud`). LotAtc
(8 736 lines): 1 680 lines of configuration dump, 1 511 airport-status lines, ~2 200 lines of client
connection life cycle, of which 1 062 at `[W]` (`Init`, `Finish`, `Client deleted`, and
*"The remote host closed the connection"*, a normal disconnection).

The side panel lists every noise family that is hidden by default, even at zero: on a DCSSB log,
21 empty DCS families.

## Ticket

| # | Ticket | Status |
|---|--------|--------|
| [01](tickets/01-per-line-header-formats.md) | Per-line header formats, format-bound sources, DCSSB and LotAtc noise families, panel shows only families met | ✅ |

## Definition of done

- Each format above is split into one entry per record, with its time, level and source label.
- A line matching no format stays a continuation only after a recognised header; an unknown format
  (`debrief.log`) reads line by line instead of one block.
- Script prefixes (VEAF, CTLD…) are recognised on DCS lines only.
- Noise families `dcssb_mission_events`, `dcssb_polling`, `lotatc_config_dump`, `lotatc_airports`,
  `lotatc_client_cycle`, hidden by default.
- The side panel lists a noise family only once it has been met; its title is "Bruit".
- Tests on real samples of every format; `LOGS.md` / `LOGS.en.md` updated; CHANGELOG.
