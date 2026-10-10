# 02 — The server build, through a profile

Status: ✅ done

Type: docs

Step 2 disables security and says to restore it before deploying, without saying how. New step: move `security: disabled: true` into a `TEST` profile, build with `--profile TEST` while testing and without a profile for the server. Warn that a misspelt profile falls back to the base configuration, security on.
