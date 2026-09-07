# 01 — The container does not run under the product's name

Status: ✅ done

Type: fix

## What to build

The image creates its unprivileged account as `veaf`. Rename it to something the domain never says —
`appuser`. One line of `Dockerfile`, plus the `chown` beside it.

The uid stays **10001**: it is what a deployment `chown`s the GitHub App's private key to, and the
README tells operators to do exactly that. Changing the name is invisible to them; changing the
number would silently make the key unreadable, which is the failure that starts a bot answering
`/ask` and failing every report.

## Why not simply rely on ticket 02

Because they close different holes. Ticket 02 stops the redactor from eating a word the product
uses; this one stops the service from *being named after one*. A deployment that renames its user
back to `veaf` would resurrect the bug through a path ticket 02 cannot see — the account name is
whatever the machine says it is.

And it is the immediate fix: the image is rebuilt on merge, so the deployment is repaired within
minutes without waiting for the tools' own release.

## Done when

- the container's account is `appuser`, uid unchanged at 10001;
- a report filed from it says `veaf-tools`, and its marker is intact;
- the CI's container job still passes, including the step that reads the mounted key.
