# 02 — A campaign mission silences the ATC

Status: ✅ done
Type: fix

## Found

David, 2026-10-08, during the flight: "silenceATC".

The option exists, `mission.silence_atc_on_all_airbases` in `mission.yaml` (`veaf.silenceAtcOnAllAirbases()`), and VEAF missions converted from v5 carry it on.
In *Kolkhida* it is only in the generated comment, both in the campaign's `template/mission.yaml` and in mission 1's: the ATC was not silenced.

Confirmed by David the same evening: the ATC is to be silent, as on the other VEAF missions.

## To do

- Decide where the default lives: the template a campaign is started from, or `campaign next` writing it into each mission folder (and keeping a value edited since, like the rest of the folder).
- Test and doc (`CAMPAIGN.md` FR + EN).

## Done when

A mission built by `campaign next` silences the ATC on every airbase unless its `mission.yaml` says otherwise.

## Decided (2026-10-09)

The campaign folders are written by Claude, nothing edited by hand: `campaign next` writes `mission.silence_atc_on_all_airbases: true` when the key is absent.
