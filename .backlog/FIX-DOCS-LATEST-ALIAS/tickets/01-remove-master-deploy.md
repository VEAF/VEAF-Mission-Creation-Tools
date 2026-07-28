# 01 — Remove the master deploy step and free the `latest` alias

Status: ✅ done
Type: fix

## Tasks

- [x] `docs.yml`: drop the `master` deploy step (with the reason inline so nobody restores it)
      and remove `master` from the branch triggers.
- [x] Delete the parasite `latest` **version** from `VEAF/documentation` `gh-pages`
      (`versions.json` entry + directory) — checked in dry-run first, then applied.
- [x] Re-run the failed `Deploy Docs` run for tag `v6.11.2` → success.
- [x] Verify on the live site: `6.11.2` carries `aliases: ["latest"]`, `latest` is a redirect,
      and `dev` / `6.10.0` / `v5` are untouched.

## Note

`mike` could not run locally (`No module named 'material.plugins.search'` — a local
environment conflict), so the site cleanup was done by editing the `gh-pages` branch directly,
which is what mike does under the hood. Worth fixing separately if we ever need mike locally.
