# 04 — remote journal over SFTP (if time allows)

Status: ✅ done — 2026-10-24
Type: feature

Read a remote journal through a local mirror, key or agent authentication, with `golang.org/x/crypto/ssh` and `github.com/pkg/sftp`, as `remote.py` does.

Done: `internal/logcore/remote.go` (mirror, rotation, bounded download, reconnection with a delay) and `internal/sshlog` (key/agent authentication, `known_hosts` check, the `servers` block of `~/veafmct.yaml`), tested against an in-process SSH + SFTP server and, read-only, against dcs.veaf.org (50 236 entries of `veaf/private1` in 1.5 s). `veaf-logs --remote SERVER/INSTANCE`, `--servers` to list them.
Not done: a host-key prompt (an unknown host is refused with the `ssh` command to run once), the Windows OpenSSH agent pipe, passphrase-protected keys outside an agent.
