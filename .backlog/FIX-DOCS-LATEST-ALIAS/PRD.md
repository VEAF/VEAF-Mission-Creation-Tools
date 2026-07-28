# FIX-DOCS-LATEST-ALIAS — released documentation was never published

Status: ✅ done

## Symptom (spotted by David)

The documentation site's version picker still advertised **6.10.0** as `latest`, although
6.11.0 had shipped weeks earlier. `dev` was current, so only *released* documentation was
stuck.

## Two causes, one behind the other

**1. A missing tag.** Two tag families exist and do different jobs:

| Tag | Triggers |
|---|---|
| `published-vx.y.z` | the GitHub Release — executables, `published.zip`, the capture kit |
| `vx.y.z` | the **versioned documentation** (`mike deploy "$VERSION" latest`) |

The release skill only documented the first, so 6.11.0 got `published-v6.11.0` and never
`v6.11.0`: its documentation was simply never deployed. Fixed in the skill (both tags, what
each one triggers, and what breaks when the `v*` one is forgotten).

**2. A workflow that could not succeed anyway.** Pushing `v6.11.2` then failed with:

```
error: alias 'latest' already specified as a version
```

`docs.yml` had two contradictory steps:

- push to `master` → `mike deploy … latest` creates a **version** literally named `latest`
- tag `v*` → `mike deploy … "$VERSION" latest` wants `latest` as an **alias**

Once the version existed, mike refused the alias and the tag deploy failed every time.

**Why it appeared only now**: the `master` step never ran before, because every workflow was
scoped to a non-existent `main` branch. `FIX-WORKFLOWS-MAIN-TO-MASTER` renamed those triggers
to `master` — reviving a step that created the parasite version and broke tag deploys. A fix
that woke a dormant bug.

## Fix

- **`docs.yml`**: the `master` deploy step is removed (documentation of a release is published
  by its `v*` tag, which is also the single source of truth for `latest`), and `master` is
  dropped from the branch triggers since the job would otherwise run and deploy nothing.
- **Site cleanup**: the parasite `latest` *version* was deleted from `VEAF/documentation`
  `gh-pages` (entry in `versions.json` + its directory), freeing the alias.
- **Redeploy**: the failed `v6.11.2` run was re-run and succeeded.

## Verified on the live site

`versions.json` now reads: `dev`, **`6.11.2` with `aliases: ["latest"]`**, `6.10.0`, `v5` —
and `latest` is a 6-byte redirect instead of a duplicated directory tree.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Remove the conflicting master deploy step, clean the parasite version, redeploy | ✅ |
