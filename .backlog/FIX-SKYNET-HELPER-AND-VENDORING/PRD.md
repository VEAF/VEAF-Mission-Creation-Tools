# FIX-SKYNET-HELPER-AND-VENDORING — the VMCT half of The Reaper's report

Status: ⬜ ready

Origin: The Reaper, 2026-09-17, on a mission built with veaf-tools:

> *"J'ai configuré Skynet sur une mission avec les outils VEAF. J'ai un problème, quand il y a des
> EWR rouge à portée, les SAM ne s'allument pas même si on est à portée voire très proche. Quand il
> n'y a plus d'EWR rouge, les SAM deviennent autonomes et actifs."*

Mission `VEAF_OpenTraining_Caucasus_v6_20260917_debug_skynet_1705.miz`, same `dcs.log` as the CTLD
report of the same evening.

## Read this first: the work is split across two repositories

**Skynet is maintained by VEAF**, in [`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS) — the
Regroupement's repository is read-only and walder has been inactive for years. That repository has
separate sources (`skynet-iads-source/*.lua`), its own build and its own test suite; the
`src/scripts/community/skynet-iads-compiled.lua` carried here is the **build artifact**, and editing
it directly would be lost at the next build.

So the fix itself — the last line of defense, and the coverage refresh — lives in the Skynet
repository, in its `FEAT-LAST-LINE-OF-DEFENSE` lot. **This lot is the VMCT half only**: what belongs
to `veafSkynetIadsHelper.lua`, the documentation, and bringing the new Skynet version in.

## What was found, in one page

A SAM held by the network has its emission switched off, so it is blind: it only lights up when an
EWR **that covers it** hands it a contact. Fly under the EWRs' horizon and nothing reacts, whatever
the distance. Kill the EWRs and the sites revert to the DCS AI, which lights everything up — hence
the inversion the reporter describes.

Measured on his log, 24 minutes of 5 s cycles: **7 933** SAM status lines dark under network control,
**zero** ever lit, the only two active sites being the pair that had no EWR parent. Stated honestly:
the closest contact to any network EWR in that log is 51.85 NM, so his own close pass is not in this
log — the mechanism is proven from the code, not from this measurement.

Settled with Flogas and the historical IADS developers on 2026-09-19, then grilled on the design the
same day. The full decision record lives in the Skynet lot; what matters here is that the fix exists
elsewhere and this lot carries its consequences on the VMCT side.

## Tickets

| # | Ticket | Depends on |
|---|---|---|
| 01 | [Remove the two dead `actAsEW` reset blocks](tickets/01-remove-the-dead-actasew-blocks.md) | nothing — shippable now |
| 02 | [Document what a network SAM does and does not see](tickets/02-document-what-a-network-sam-sees.md) | ~~the Skynet release~~ — **released** |
| 03 | [Vendor the new Skynet version](tickets/03-vendor-the-new-skynet-version.md) | ~~the Skynet release~~ — **released** |
| 04 | [Repair the Skynet drift watch, which can no longer fire](tickets/04-repair-the-skynet-drift-watch.md) | nothing — shippable now |

The lot ships as **one PR**, once the Skynet side is released. Ticket 01 is independent and could go
first, but David chose a single PR per repository on 2026-09-19.

## The blocker is lifted — 2026-09-21

[**Skynet 3.5.0**](https://github.com/VEAF/Skynet-IADS/releases/tag/v3.5.0) is published, the first
release under joint VEAF / Regroupement de Patrouilles (BFR, NAWACS) maintenance. It carries the last
line of defense and the coverage refresh this lot was waiting for, plus three coverage fixes that are
not in the artifact carried here, and `SkynetIADS:reportContact` — which is what
[`FEAT-SPOTTER-NETWORK`](../archive/FEAT-SPOTTER-NETWORK.md) needs to close its in-game check.

The release itself is a **downloadable asset**, so vendoring no longer means recompiling from
sources. That, and the fact that the drift watch pointed at a file this repository no longer commits,
is what ticket 04 is about — read it before touching `vendored.yaml`.

## Definition of done

- The five-NATO-name `actAsEW` resets are gone, and an explicit EW-watch request survives any group
  joining the network.
- `mission.yaml` carries the new SKYNET keys, and `src/defaults/mission-folder/mission.yaml` is
  aligned in the same lot (CLAUDE.md §9.7).
- Both documentation languages updated, `poetry run docs-check` green.
- The vendored artifact is **executed** against the DCS mocks, not merely loaded — see
  `tests/ci/smoke`-style checks. Parsing a file says nothing about a main chunk that raises, which is
  exactly what let CTLD rc8 through and killed every radio menu (#957).
- `poetry run test-lua` green.
