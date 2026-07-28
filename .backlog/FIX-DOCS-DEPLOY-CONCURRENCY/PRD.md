# Lot FIX-DOCS-DEPLOY-CONCURRENCY — two concurrent docs deployments knock each other out

Status: ⬜ ready
Branch: —

## Problem Statement

Observed live on 2026-07-28 while republishing the 6.12.0 documentation
([run 30397447889](https://github.com/VEAF/VEAF-Mission-Creation-Tools/actions/runs/30397447889)):

```
error: failed to push branch gh-pages to ext-docs:
   ! [rejected]          gh-pages -> gh-pages (fetch first)
```

The manual republish ran while the `Deploy Docs` run triggered by the #645 merge on `develop` was
still going. Both jobs fetch `gh-pages` from the external `VEAF/documentation` repository, build,
and push it back. The second to push is rejected: it fetched before the first one landed.

Re-running once the other job had finished worked, so nothing is broken in the workflow's logic —
`Deploy Docs` simply has no protection against running twice at once.

## Why it matters

The failure mode is a **silently unpublished documentation**. The most likely collision is the worst
one: a `v*` release tag pushed while a `develop` merge is still deploying. The tag's job loses the
race, the release documentation is never published, and the site's `latest` keeps pointing at the
previous version — which is precisely the defect that left the site on 6.10.0 after 6.11.0 shipped
(FIX-DOCS-LATEST-ALIAS). Nothing in the release procedure would catch it; the run is red in a tab
nobody is watching, and the site simply looks unchanged.

The window is real, not theoretical: the release procedure pushes `published-v*` and `v*` together,
and a back-merge to `develop` follows minutes later.

## Solution

A `concurrency` group on the `Deploy Docs` workflow so deployments queue instead of colliding:

```yaml
concurrency:
  group: deploy-docs
  cancel-in-progress: false
```

`cancel-in-progress: false` matters — cancelling would drop a deployment on the floor, which is the
very outcome to avoid. Queuing costs a couple of minutes and loses nothing.

Worth checking at the same time whether the `gh-pages` fetch/push should retry on rejection, since a
queue removes the collision but not an unrelated concurrent push to `VEAF/documentation`.

## Definition of Done

- [ ] `concurrency` group on `.github/workflows/docs.yml`, with `cancel-in-progress: false`
- [ ] verified by triggering a `develop` push and a manual republish back to back: the second waits
      instead of failing
- [ ] `CHANGELOG.md` entry, PATCH version bumped

## Out of Scope

The other workflows: only `Deploy Docs` pushes to an external repository, so it is the only one
where two runs contend for the same ref.
