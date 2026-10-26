# 02 — `api:` servers in `~/veafmct.yaml`, instances discovered

Status: ⬜ ready

The `servers` block (`internal/sshlog`, `ConfigPaths`, the parser and its tests) takes a second kind of server:

```yaml
servers:
  veaf-api:
    api:
      url: https://dcs.veaf.org          # the RestAPI, behind HTTPS
      api_key_file: ~/.veaf/dcssb-api-key
      # prefix: /api                     # if the RestAPI has one
    # logs:                              # optional: narrow or rename what is discovered
    #   private1: {instance: private1}
    #   bot: {node: dcs-veaf-org}
```

- A server has either `host` (SSH) or `api`, never both; the error says which.
- Without `logs:`, the instances come from `/servers` and the bot log from `/node/logs` (the API's own node).
- The key is read from `api_key_file` when the connection opens and kept in memory only: not in `session.json`, not in an error, not in the `/bug` report (a test greps for it).
- A 403 says what to change on the server: an API key accepted on these endpoints from where the viewer connects (`endpoints.<path>.security.remote: api_key` in `restapi.yaml`).
- `http://` is accepted for `127.0.0.1` and `localhost` only (an SSH tunnel); any other host needs `https://`.

## Done when

- Parser tests: an API server, a mixed config, both `host` and `api`, no `url`, a missing key file, `http://` to a remote host refused.
- Discovery tested against `httptest`: servers listed, `logs:` narrowing and renaming, a 403 with its hint.
