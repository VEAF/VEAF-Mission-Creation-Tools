# FIX-DOC-LATEST-LINKS — a link copied from the docs should follow the newest release

Status: ✅ done — shipped in #1211 · archived 2026-11-24

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

- [01 — Landing page "latest" card](FIX-DOC-LATEST-LINKS.md)
- [02 — Version selector opens /latest/](FIX-DOC-LATEST-LINKS.md)

## Tickets, in full

## 01 — Landing page "latest" card

Status: ✅ done

When `versions.json` has a release carrying the `latest` alias, the landing page shows a featured "latest" card opening `./latest/`, titled with that release's number; the numbered card stays, with its "latest" badge, and is no longer featured.

Checked on a local mike-like layout: cards `./latest/` (featured), `./dev/`, `./6.33.0/`, `./6.32.0/`.

## 02 — Version selector opens /latest/

Status: ✅ done

`extra.version.alias: true` shows "latest" next to the newest release in the selector; `doc/assets/version-latest.js` catches the click on that entry (capture phase, before Material's handler) and opens the same page under `/latest/`, or `/latest/` itself when the page does not exist there.

Checked on a local mike-like layout: 6.33.0 → `/latest/pilot/GUIDE/#top`; dev → `/latest/pilot/GUIDE/#top`; a page missing from latest → `/latest/`; latest → dev still handled by Material (`/dev/pilot/GUIDE/#top`).
