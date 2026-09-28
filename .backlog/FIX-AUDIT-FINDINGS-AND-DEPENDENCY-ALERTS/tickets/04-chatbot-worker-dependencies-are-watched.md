# 04 — the chatbot Worker's dependencies are watched

Status: ✅ done — 2026-09-28

Source: Dependabot alert #59 (high), open on 2026-09-28.

## The alert

`poc/doc-chatbot/worker/package-lock.json` locks `sharp` 0.35.2, affected by two libheif advisories
(GHSA-g89c-p67h-r497, GHSA-2jg2-4ch7-h545), fixed in 0.35.4. It is a **dev** dependency, pulled by
`wrangler` → `miniflare` for the local `wrangler dev` server. The deployed Worker never contains
it, so exposure is limited to a maintainer's machine running `wrangler dev` on a hostile image —
which that server never processes. Real, low practical risk, and cheap.

## Why no PR ever came

`.github/dependabot.yml` watches two ecosystems, both at `/`: `pip` and `github-actions`. So:

* `poc/doc-chatbot/worker` (npm) is **not watched** — the alert exists, the PR never will;
* `services/support-bot` (its own `pyproject.toml` and `poetry.lock`) is **not watched** either,
  although it is deployed and holds the Discord token.

## What to do

* Bring `sharp` to ≥ 0.35.4 in the Worker's lock (`npm update sharp`, or bump `wrangler` if
  `miniflare`'s range does not allow it). Check `wrangler deploy --dry-run` still builds.
* Add two `updates` entries to `dependabot.yml`: `npm` at `/poc/doc-chatbot/worker` and `pip` at
  `/services/support-bot`, with the same grouping and target branch as the existing `pip` entry.
  `target-branch` must **not** be set: `develop` is the default branch, and naming a target branch
  turns security updates off for that entry.

## Check

The alert closes by itself once the lock on `develop` carries 0.35.4 — verify with
`gh api repos/VEAF/VEAF-Mission-Creation-Tools/dependabot/alerts/59 --jq .state` after the merge.
