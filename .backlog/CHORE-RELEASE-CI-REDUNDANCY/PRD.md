# CHORE-RELEASE-CI-REDUNDANCY — stop re-testing a release three times

Status: ✅ done — 2026-11-05

## Why

The 6.36.0 release started 27 workflow runs, and 15 of them re-tested code already tested.
The release pull request's head, the merge commit on `master` and the back-merge on `develop` all had tree `42fcb60e`: the push to `master` re-ran nine workflows (DCS Data Consistency and DCS Mock Coverage included, since their path filter compares with the previous release) and the back-merge seven, two of them Python Quality at about ten minutes.
Nothing waited on them — the Release job started two seconds after the tag, and the repository is public — but they took runner slots from other pull requests and buried the release's own runs in the Actions list.

## What changes

- The check workflows no longer run on a push to `master`: Python Quality, Lua CI, Go CI, Docs Check, Secret Scanning, DCS Data Consistency, DCS Mock Coverage, and SBOM, whose release copy comes from the `published-v*` tag.
  `master` only receives release pull requests, which ran those checks against it.
- `support-bot-ci.yml` and `chatbot-worker.yml` keep `master`: their push publishes the bot's `latest` image and the chatbot worker.
- The back-merge of the release procedure carries `[skip ci]` (`.claude/commands/release.md`, `doc/developer/GUIDE.md` and `.en.md`).
  The `dev` docs and the `develop` SBOM and bot image catch up on the next merge into `develop`.
- `test_ci_trigger_paths.py` fails if one of those checks triggers on `master` again, or stops triggering on `develop`.

## Definition of done

- The new test red on the old workflows, green on the new ones.
- Python suite and Docs Check green.
- `CHANGELOG.md` under `[Unreleased]`.

## Not claimed

Measured on the next release only: that its merge on `master` starts only the two publishing workflows, and its back-merge none.
