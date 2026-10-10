# FEAT-CAMPAIGN-INTEL-DELAY — the other side hears of an assault convoy later, as intelligence would

Status: 🧑 waiting-human — merged on `develop` (#1106); to be checked in game

## Need

David, 2026-10-08, preparing *Kolkhida* mission 1: "fais en sorte qu'on n'ait pas de message sur le départ du convoi rouge tout de suite, mais bien plus tard (pour simuler le délai de renseignement)".

`veafCampaign.sendConvoy` told both sides at the second a convoy left — its own side, and the other as intelligence — and drew its axis for everybody (`lineToAll(-1, …)`), so blue saw the red column on its map before any intelligence could have reached it.

## What the lot does

- A new rule, `rules.intel_seconds` in `campaign.yaml` (1200 s by default, 0 for at once), passed to the mission like `assault_seconds`.
- The convoy's own side is told and sees its axis at once; the other side gets the intelligence message **and** the axis line on its map together, `intel_seconds` after the convoy left, once — and never for a convoy destroyed before then. Both lines go when the convoy arrives or is destroyed.
- The delay is my choice of default, not David's: 20 minutes against a convoy that takes about 1 h 15 from Kobuleti to Poti.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-intel-delay.md) | The intelligence delay, in flight and in `campaign.yaml` | ✅ |

## To check in game

On *Kolkhida* mission 1: no message about the Senaki column for blue when it leaves (about 06:15), then the message and the red line about twenty minutes later (about 06:35).
