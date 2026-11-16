# 01 — skip the runs a release merge repeats

Status: ✅ done — 2026-11-05

Drop `master` from the `push.branches` of the eight check workflows, add `[skip ci]` to the back-merge command of the release procedure, and guard the first with a test.

## Acceptance

- `TestChecksDoNotRerunOnAReleaseMerge` fails on the workflows of `develop` before the change and passes after.
- `support-bot-ci.yml` and `chatbot-worker.yml` still trigger on `master`.
