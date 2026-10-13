# 10 — `describe_known_limitations` is 74 000 characters: it overflows the agent's tool result

Status: ✅ done
Type: feat (small)
Files: `veaf_mission_mcp/actions.py` (`describe_known_limitations`), `veaf_libs/data/known-limitations.yaml`, the authoring skill

## What happens

The Open Training prompt tells the agent to read the limitations first. The result is 73 957 characters over 591 lines (`veaf_tools_version 6.29.0`): the client refuses it (« exceeds maximum allowed tokens ») and saves it to a file, which the agent reads back in 300-line pieces — about 19 000 tokens, of which a WW2 Normandy mission needs perhaps ten entries. Ticket 14 of FIX-OPEN-TRAINING-SYRIA-FINDINGS did the same for `list_catalog`.

## What ships

- `describe_known_limitations(area=…, theatre=…, full=false)`: by default the `id`, `kind`, `area`, `title` and the one-sentence workaround of each entry (about 8 000 characters); `area` filters (`spawning`, `air-defence`, `players`, `radio`, `mcp`, `runtime`, `pipeline`, `scripting`); `full` returns today's text; `describe_known_limitations(id=…)` returns one entry.
- The prompt says: read the short list, then the entries of your areas.
- Entries that only concern one theatre (`no-parking-data-outside-three-theatres`, `marianas-placement-checks-nothing`) carry `theatres: [...]` so `theatre=` drops the others.

## Done when

The default call fits comfortably in a tool result and each long entry is one call away.

## Done

`describe_known_limitations` with no argument returns a short listing — `id`, `kind`, `area`, `title`, and the count of each area — about 12 400 characters instead of 74 000. The ticket's « about 8 000 characters with the one-sentence workaround » does not hold: the titles alone are 6 000. `area`, `kind` or `id` (one or a list) return the entries in full; `theatre` drops the entries whose `theatres` list does not name it (`no-parking-data-outside-three-theatres` and `marianas-placement-checks-nothing` carry one); `full` returns everything. The skill, the Open Training prompts and the developer doc say to read the short list first.
