# Issue tracker: local `.backlog/` directory

Lots, PRDs, and tickets for this repo live as markdown under `.backlog/`.

## Conventions

- One lot per directory: `.backlog/<LOT-ID>/`
- The PRD is `.backlog/<LOT-ID>/PRD.md` (Matt's PRD template; no separate `## Goal`)
- Tickets are `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`, numbered from `01` in dependency order
- Status is a `Status:` line near the top of each PRD/ticket file (see `triage-labels.md`)
- The lot index (Summary table of every lot + status) is `.backlog/README.md`, maintained by hand
- Completed lots are moved to `.backlog/archive/<LOT-ID>.md` (compact, ticket table preserved) once closed > 3 days

## When a skill says "publish to the issue tracker"

- A PRD → write `.backlog/<LOT-ID>/PRD.md`, create the directory if needed, and add a row to `.backlog/README.md`.
- An issue → write `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`.
- New artifacts are created at `Status: ⬜ ready`.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user normally passes the lot ID or ticket path directly.
