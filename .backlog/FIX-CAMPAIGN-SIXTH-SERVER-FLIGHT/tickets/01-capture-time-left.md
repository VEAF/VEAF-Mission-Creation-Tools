# 01 — The capture shows the time left

Status: 🧑 waiting-human — the flight check
Type: fix

## To do

- First, a failing test: a capture held 120 s out of 600 shows 8 min left, on the map label and in the situation line; a helicopter capture counts down from `helicopter_capture_seconds`.
- `campaign.map_label_capture` and `campaign.situation.capture` (FR/EN): the time left, `veafCampaign.captureSeconds(byHelicopter) - capture.seconds`, in minutes and seconds (`4 min 30 s`, `45 s`), never below zero. Reco: "capture bleue en cours, prise dans 4 min 30 s".
- The `campaign.check.capture` debug line may keep the elapsed time; say which it shows.
- Docs: the campaign page where the capture is described; CHANGELOG entry.

## Done when

Every player-facing capture timer counts down to the capture; with tests.

## Flight check

On the Campagne server: a neutral zone being taken shows a countdown on the F10 map that ends with the capture.

## Done (2026-11-23)

- `veafCampaign.captureTimeLeft(capture)`: `captureSeconds(byHelicopter) - capture.seconds`, rounded up, never below zero, as `4 min 30 s`, `8 min` or `45 s`.
  `checkCapture` records `capture.byHelicopter` (saved with the capture), so a capture by landed helicopters alone counts down from `helicopter_capture_seconds`.
- `campaign.map_label_capture` and `campaign.situation.capture` (FR/EN): "capture bleu en cours, prise dans 4 min 30 s" / "blue capture in progress, taken in 4 min 30 s".
  The French keeps the side word the campaign's other lines use (`bleu`, `rouge`).
- The `campaign.check.capture` line of the self-check (admin) keeps the elapsed time: it is a debug readout, next to the zone's presence log.
- The sitac block (`persistent.state`) keeps `seconds` held: the web map reads raw data.
- Tests: `test_a_capture_counts_down_to_its_end` (120 s of 600 → 8 min; 45 s; 0 s past the end), `test_a_helicopter_capture_counts_down_from_its_own_delay`, and the map label and situation tests updated.
- Docs: *Campaign* and *Persistent campaign* (FR/EN).
