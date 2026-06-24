# Triage labels → local Status vocabulary

This repo uses a single `Status:` line (one value at a time). Matt's five triage
roles map onto it as follows:

| Status        | Emoji | Matt triage role(s)            |
|---------------|-------|--------------------------------|
| ready         | ⬜    | ready-for-agent                |
| waiting-human | 🧑    | ready-for-human, needs-info    |
| wontfix       | 🚫    | wontfix                        |

Lifecycle-only states (no triage-role equivalent): `in-progress` 🔄, `done` ✅.

`needs-triage` is not used — lots are created already specified, not triaged from
raw external reports. `/to-prd` and `/to-issues` create artifacts at `ready` ⬜.
