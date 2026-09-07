# Triage labels → local Status vocabulary

This repo uses a single `Status:` line (one value at a time). Matt's five triage
roles map onto it as follows:

| Status        | Emoji | Matt triage role(s)            |
|---------------|-------|--------------------------------|
| ready         | ⬜    | ready-for-agent                |
| waiting-human | 🧑    | ready-for-human, needs-info    |
| wontfix       | 🚫    | wontfix                        |

Lifecycle-only states (no triage-role equivalent): `in-progress` 🔄, `done` ✅,
`paused` ⏸.

`paused` ⏸ means **deliberately parked** — the work is specified and could start, but a
decision was taken not to continue for now. It is not `waiting-human` 🧑, which says a
human is *blocking* (a test to fly, a question to answer); nothing is expected of anyone
for a paused item. It is not `ready` ⬜ either, which would invite an agent to pick it up.
Use it on a lot whose remaining tickets are shelved, or on a single shelved ticket inside
an otherwise finished lot. Record *why* on the same line — a paused item with no reason
is indistinguishable from a forgotten one.

`needs-triage` is not used — lots are created already specified, not triaged from
raw external reports. `/to-prd` and `/to-issues` create artifacts at `ready` ⬜.

## GitHub labels the support bot files under

The Discord support bot files issues on the tracker, and they are recognisable by their
labels rather than by their author — the author is a GitHub App, which reads as a name
nobody knows.

| Kind | Labels |
|---|---|
| A bug report, from `/bug` | `bug` + the component's label + `filed-by-bot` |
| A suggestion, from `/suggest` | `enhancement` + `filed-by-bot` |

**Machine-filed suggestions carry no label of their own** (decided 2026-09-06). The pair
`enhancement` + `filed-by-bot` already isolates them exactly, and a third term would be
vocabulary to maintain here for a filter that can already be written:
`label:enhancement label:filed-by-bot`.

Both kinds carry a **Prior art** / *What was checked before opening this* section in the
body, listing what was consulted and what it answered. On a suggestion that section also
distinguishes two states that must never be read as one: *the documentation says nothing
about this* — a finding, and a hint that a page may be missing — and *the documentation
could not be asked*, which means the check did not happen at all.
