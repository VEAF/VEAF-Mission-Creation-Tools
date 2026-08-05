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
