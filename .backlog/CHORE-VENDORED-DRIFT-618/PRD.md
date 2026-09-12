# CHORE-VENDORED-DRIFT-618 — clear the drift watch, and say what it cannot see

Status: 🔄 in-progress

[#618](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/618) is the standing recap issue the
`vendored-drift-watch` workflow edits in place. On 2026-09-12 it reported two drifted artefacts and
one error. Measured rather than believed: **Skynet was already back in step** (its pin was bumped
after the issue body was last written), so the real work was TUM, CTLD, and one finding.

## What was synced

| Artefact | From | To | Why it is safe to take verbatim |
|---|---|---|---|
| CTLD | 2.0.0-rc7 | **2.0.0-rc8** | VEAF's own rewrite. Release notes: *"No existing setting was renamed or removed, and every default keeps today's behavior."* 410 added / 30 removed lines, matching the notes. Two of the fixes were reported by David. |
| TUM | 0.1.250722 | **0.3.251019** | Opt-in and **off by default** (`TUM: false` in the shipped `mission.yaml`), so no existing mission changes behaviour unless it asked for TUM. No new resource dependency, and the BLUFOR/REDFOR zone contract our validator checks is unchanged. |

CTLD's configuration catalogue is read **out of** the vendored `CTLD.lua` (ADR 0016), so rc8's two
new settings (`troopPickupAtFARP`, `farpTroopPickupRadius`) reach the next scaffold with nothing to
update on the Python side.

## Two traps met on the way, now written into `vendored.yaml`

- **TUM has no `.lua` asset.** A release ships `.miz` files and PDFs. The script lives inside each
  mission as `l10n/DEFAULT/Script.lua`; it is byte-identical across theatres (checked on Marianas and
  Syria). The old `manual_steps` told you to re-download a file that has never existed.
- **TUM's own version constant lies**: `TUM.VERSION_STRING` still reads `0.1.250722` inside the
  v0.3.251019 release. The release tag is the only trustworthy version, which is why the artefact
  cannot join `SELF_DECLARED` in `test_vendored_pins_match_the_files.py`.

## Verified here, and what is still not claimed

Both files load cleanly under a real **Lua 5.1** interpreter — the version DCS runs:

```
"/c/Program Files (x86)/Lua/5.1/lua.exe" -e "assert(loadfile('<file>'))"   -> OK for both
```

Worth stating how that was nearly missed: `lua` **on the PATH** here is scoop's 5.5, where a `for`
control variable is `const`, so it rejects both the incoming *and* the outgoing file — a check that
fails either way decides nothing. The 5.1 binary is installed off-PATH at the path above; see
[[lua-tests-need-lua-51]], which says exactly this and which the first pass of this lot did not
consult, concluding instead that no 5.1 existed on this machine.

Syntax is not behaviour: **neither artefact was run in DCS**. That guarantee is the one the previous
pin already had — upstream ships these files inside missions people fly.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Sync CTLD rc8 and TUM v0.3](tickets/01-sync-ctld-and-tum.md) | ✅ |
| 02 | [The watch is blind to pre-releases](tickets/02-the-watch-is-blind-to-pre-releases.md) | ⬜ |

## Definition of done

- [x] `poetry run check-vendored` reports **0 drifted**
- [x] `vendored.yaml` pins match the files (`test_vendored_pins_match_the_files.py`)
- [x] The TUM entry's `manual_steps` describes a procedure that can actually be followed
- [ ] Ticket 02 decided by David — it changes what the weekly issue reports, which is his call
