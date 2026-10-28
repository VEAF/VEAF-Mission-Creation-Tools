# FIX-DOC-LATEST-LINKS — a link copied from the docs should follow the newest release

Status: 🔄 in-progress

Origin: David, 2026-10-28 — "there is no real 'latest' section in the published docs; when you browse and want to give a link, it is always tied to a specific version".

## What was wrong

- mike publishes and serves the `latest` alias (`/documentation/latest/…` answers 200 with the 6.33.0 pages), but nothing leads there.
- The landing page (`src/docs-landing/index.html`) builds every card as `./<version>/`: the featured card, the one with the "latest" badge, opened `/6.33.0/`.
- Material's version selector links every entry to `../<version>/` (`bundle.*.min.js`, Material 9.7.7), with no setting to link an alias instead.
- So a reader browsing from either entry point reads `/6.33.0/…` in the address bar, and the link they share goes stale on the next release.

## Decided (David, 2026-10-28)

- a. The landing page opens on a "latest" card pointing at `./latest/`; the numbered releases stay listed below it for a link that must not move.
- b. The version selector shows the alias (`extra.version.alias: true`), and a small script sends the entry carrying `latest` to `/latest/`, on the same page when it exists there.
- Not done: documenting "replace the number with `latest` in the URL" — the step nobody takes.

## Tickets

- [01 — Landing page "latest" card](tickets/01-landing-latest-card.md)
- [02 — Version selector opens /latest/](tickets/02-selector-latest.md)
