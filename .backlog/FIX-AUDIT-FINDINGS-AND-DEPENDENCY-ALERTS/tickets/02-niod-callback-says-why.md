# 02 — a failing NIOD callback says why

Status: ⬜ ready

Source: `davidp57/security-audits#90`, checked against the code on 2026-09-28.

## The two defects

`veafRemote.addNiodCallback` (`src/scripts/veaf/veafRemote.lua:55-113`) wraps every remote callback,
`login` included, and loses its error message on both of its failure paths:

1. **The `pcall` message is replaced by `false`** (105-109). In the `else` branch `status` is
   `false` by construction; the message is in `retval`, and the caller always receives
   `an error occured : false`.
2. **The parameter errors never reach the log** (96-99). The format carries one `%s`, for the
   callback name; `errorMessage` — which parameters are missing, unknown or of the wrong type — is
   a surplus argument that `string.format` drops. The log line stops at its colon. The caller does
   get it (`return errorMessage`), the server log does not.

The right form is already in the same file, a hundred lines lower (`veafRemote.lua:201-210`).

Practical weight is modest: the whole function sits under `if niod then`, so it only matters on a
server running NIOD. It is a two-line fix, and both lines are on the path whose purpose is to
report a failure.

## What to do

* Line 108: `veaf.p(retval)`.
* Lines 96-99: add the second `%s` so `errorMessage` is logged.

## Test

`test/lua/test_veafRemote.lua` does not exercise `addNiodCallback`. With a stub `niod` table:

* a callback whose `code` raises `"boom"` → the returned text contains `boom`, not `false`.
  **Fails before the fix.**
* a call missing a mandatory parameter → the logged `error` line names that parameter.
  **Fails before the fix.**
