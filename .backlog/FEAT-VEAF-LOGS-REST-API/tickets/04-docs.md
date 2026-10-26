# 04 — `LOGS.md` / `LOGS.en.md`: reading a server's logs through its RestAPI

Status: ⬜ ready

The `#remote` section of `doc/mission-maker/LOGS.md` and `LOGS.en.md` gains the API way, FR and EN, beside SSH:

- what it needs on the server: DCSServerBot with the log routes (version to state once released), the RestAPI plugin and its key, a reverse proxy with HTTPS, the `restapi.yaml` endpoint rules for an API key from the internet;
- the `api:` block of `~/veafmct.yaml`, the key file;
- what differs from SSH: no SSH account, read-only, the history a tab opens with (the last 2000 entries), the level padding not kept;
- security: the key in a file only the user can read, never the API without HTTPS, logs carry player names and IP addresses.

Plus the `CHANGELOG.md` entry.

## Done when

- Both languages say the same thing; one sentence per line in what is written or rewritten.
