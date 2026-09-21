# 03 — Vendor the new Skynet version

Status: ⬜ ready (blocked on the Skynet release)

## What this brings

The last line of defense and the coverage refresh, from
[`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS) — but **not only those**.

The artifact carried here identifies itself as `3.4.0RP-VEAF build 05.09.2026`, and the repository
has moved on since: `getCategory` centralised with its nil protection (`29da7e6`), a SAM-goes-dark
test suite (`f6d77e6`), SAM sites informed of inbound weapons (`da60f1c`), the `syknet`→`skynet`
typo sweep (`1cd651e`). So this is a version bump carrying a month of Flogas's work, not a patch
drop. Read the diff of the source repository before assuming it is inert.

## New settings to surface

All of them in `mission.yaml` under `modules.SKYNET`, David's choice on 2026-09-19 — and therefore
`src/defaults/mission-folder/mission.yaml` in the same lot, per CLAUDE.md §9.7:

| Key | Default |
|---|---|
| last line of defense on/off | **on** — it changes existing missions, say so in the PR |
| radius bounds | 10–15 km, drawn once per site |
| persistence after the last pass | 45 s |
| coverage sweep interval | 10 s |

Global for both coalitions for now; per-network only if the need appears. Note in the doc that
`dynamic_spawn` is the one key that is already per network.

## The quality gate that matters here

**Execute the artifact against the DCS mocks, do not merely load it.** `assert(loadfile(f))` parses
the file and says nothing about a main chunk that raises at run time — that is exactly how CTLD rc8
passed the gate and killed every radio menu in the mission (#957). One raise takes down the whole
concatenated loading chunk.

Also re-run the mission build end to end and unzip the resulting `.miz` to read what actually
shipped, rather than trusting the yaml.

## It also unblocks the spotter network

[`FEAT-SPOTTER-NETWORK`](../../archive/FEAT-SPOTTER-NETWORK.md) shipped on 2026-09-21 and is
**complete except for its in-game check**, which cannot run until this lands: its hand-over calls
`SkynetIADS:reportContact`, which exists in `VEAF/Skynet-IADS` and not in the artifact carried here.
Today a mission that switches the feature on gets one plain warning saying alerts travel and no site
is ever woken.

`test/veaf-tools/verify-mission-c` already runs with it on in `"radio"` mode, and its
[check 13](../../../test/veaf-tools/verify-mission-c/README.md#check-13) says what to look for. **Run
it in the same DCS session as this ticket's own verification** — it is the only debt that lot has
left, and it is invisible from anywhere but here.

## Definition of done

- The artifact matches the released Skynet version, and the version string in the file says so.
- It loads **and runs** under Lua 5.1 with the DCS mocks.
- `mission.yaml` and the shipped default carry the new keys, with the same names and defaults as the
  Skynet side.
- **Check 13 of `verify-mission-c` run and its reading recorded**, which closes
  `FEAT-SPOTTER-NETWORK`.
- `poetry run test-lua` and `poetry run pytest` green, `CHANGELOG.md` updated.
