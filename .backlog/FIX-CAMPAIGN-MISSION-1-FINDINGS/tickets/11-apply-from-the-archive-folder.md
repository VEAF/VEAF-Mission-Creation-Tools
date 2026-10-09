# 11 — `campaign apply` crashes on a state file already in its mission folder

Status: ⬜ ready
Type: fix

## Found

2026-10-09, applying *Kolkhida* mission 1 to the real campaign.
The state file had been fetched into `missions\mission-01\`, the very folder `CAMPAIGN.md` shows it in (`mission-01.state le fichier d'état écrit par la mission`).

```text
veaf-tools campaign apply <campaign>\missions\mission-01\mission-01.state <campaign>
SameFileError: …\missions\mission-01\mission-01.state and …\missions\mission-01\mission-01.state are the same file
```

`campaign_manager` copies the state file and its `.tmp` into the mission's archive folder (`shutil.copyfile(written, archive / written.name)`) before saving anything; when the source is already there, the copy raises.
Nothing was written — `campaign-state.yaml` came out byte-identical — and applying a copy taken elsewhere worked.

## To do

- Skip the copy when source and target are the same file (`Path.samefile`), keeping the copy otherwise.
- A test applying a state file that sits in its own archive folder.

## Done when

`campaign apply` accepts a state file placed in `missions/mission-NN/`, as the doc shows it.
