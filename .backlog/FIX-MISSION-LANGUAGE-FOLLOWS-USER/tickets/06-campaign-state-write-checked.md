# 06 — The campaign state write is checked (issue #1146)

Status: ✅ done

Found by the security-audits quality pass (`campagne-ecriture-etat-non-verifiee`).
`veafCampaign.writeState()` ignored what `file:write` and `file:close` answered; writes are buffered, so a full disk shows up at `close`.
A truncated temporary was then moved over the previous, valid state.

`writeTo` now checks both and fails without touching the previous file.
The remove-then-rename stays: with the temporary now known complete, a rename that fails after the remove leaves that temporary, which `campaign apply` already reads when the file is missing.

The test fake now follows the Lua 5.1 contract (`write` returns the file, `close` returns `true`, both `nil` and a message on failure).

Done when: `test_a_failed_write_keeps_the_previous_state` and `test_a_failed_close_keeps_the_previous_state` fail on the old code and pass on the new (both measured).
