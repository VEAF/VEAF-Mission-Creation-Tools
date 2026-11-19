# 05 — The sitac lists the task board

Status: 🧑 waiting-human — implemented, waits for the in-game check
Type: feature

## Decided

David, 2026-11-19, following the reco of the Foothold comparison (PRD): the sitac shows what Foothold calls its missions — ours is the task board.

## To do

- VMCT: the `sitac` block gets a `missions` list in Foothold's shape — `title`, `description`, `isRunning` (and `isEscortMission` false) — from the campaign's task board (the 3 or 4 tasks drawn from the situation, with their map mark and reward), in the players' language as the F10 menu gives them.
- foothold-sitac: the VEAF reader fills the model Foothold's missions use; a task's zone and reward shown if the page has room for them.

## Done when

The sitac lists the tasks the F10 menu offers at that moment, with tests on both sides.

## Implemented (2026-11-19)

`veafCampaignEconomy.sitacTasks()` lists the open tasks in Foothold's `missions` shape, the title as the F10 menu gives it, the air task's progress as `description`, plus `kind`, `zone` and `reward`. Tests: `TestCampaignRanking`.

## To check in game

The sitac lists the tasks the F10 menu offers.
