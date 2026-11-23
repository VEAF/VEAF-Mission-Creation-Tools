# 01 — The capture shows the time left

Status: ⬜ ready
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
