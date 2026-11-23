# 10 — What each pilot earns is not recorded

Status: ✅ done
Type: feature

## Found

David, 2026-11-17: "ça serait bien de garder combien de crédits les pilotes gagnent quand ils atterrissent, qu'on en ait une idée, histoire de voir comment on a bien réussi notre mission".
`veafCampaignEconomy.earn` writes nothing; only the loss of held credits is logged ("ERGO 2-2 | MAV loses the 15 credits held in …").
The evening's debrief could only rebuild the team's total from the `CAMPAIGN STATUS` lines (500 → 1915), and 400 credits gained around 21:35 could not be attributed.

## To do

- One log line per gain: pilot, amount, reason (kill, landing with held credits, capture, delivery, task).
- A running total per pilot kept in the campaign state, and a summary at the end of a session (mission end, or the last player leaving): who earned what, and the team's total.
- Readable after the fact without the server: written where the debrief tools can read it (the state file or a small CSV beside it).

## Done when

The next evening's debrief gives each pilot's credits from the log or the state, and a test covers the per-reason lines.

## Done

- `veafCampaignEconomy.earnBy(pilot, …)`: one `CREDITS <pilot> +<amount> (<reason>): <side total> for the side` line per gain in `dcs.log`, debug or not. A kill, its held share at landing and a warehouse delivery name their pilot; a capture, a network delivery, a task and a demolition are written under `team` (nobody's in particular).
- Each pilot's running total, by reason, is kept in the save (`parts.economy.pilots`).
- `CREDITS SUMMARY` lines at the mission's end and at the first beat where nobody is in a slot: what each pilot earned since the previous summary, best first, and the side's total.
- Tests: the per-reason lines, the totals in the save, the summary said once nobody is left.
- `PERSISTENT_CAMPAIGN.md` / `.en.md`, the debug-log section.

## In-game check

After the evening: `grep "CREDITS" dcs.log` gives one line per gain with its pilot, and a `CREDITS SUMMARY` block when the last player left.
