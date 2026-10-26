package sshlog

import (
	"path/filepath"
	"strings"
	"testing"
)

const apiConfig = `
servers:
  veaf:
    host: dcs.veaf.org
    user: veaf
    logs: {private1: 'C:\x\dcs.log'}
  veaf-api:
    api:
      url: https://dcs.veaf.org/api
      api_key_file: ~/.veaf/dcssb-api-key
  tunnel:
    api:
      url: http://127.0.0.1:9876
      api_key_file: key.txt
    logs:
      p1: {instance: VEAF Private 1}
      bot: {node: dcs-veaf-org}
`

func TestParseAPIServers(t *testing.T) {
	servers, err := ParseServers([]byte(apiConfig))
	if err != nil {
		t.Fatal(err)
	}
	if len(servers) != 3 || servers[0].API != nil {
		t.Fatalf("servers = %+v", servers)
	}
	a := servers[1]
	if a.API == nil || a.API.URL != "https://dcs.veaf.org/api" || strings.Contains(a.API.KeyFile, "~") ||
		!strings.HasSuffix(filepath.ToSlash(a.API.KeyFile), "/.veaf/dcssb-api-key") {
		t.Fatalf("veaf-api = %+v %+v", a, a.API)
	}
	if len(a.Instances()) != 0 {
		t.Fatalf("no `logs:`: the instances are discovered, got %v", a.Instances())
	}
	if target, ok := a.APITarget("VEAF Private 1"); !ok || target != (APILog{Instance: "VEAF Private 1"}) {
		t.Fatalf("a discovered server name is an instance: %+v %v", target, ok)
	}
	if target, ok := a.APITarget(BotLog); !ok || target != (APILog{}) {
		t.Fatalf("the bot log is the API node's: %+v %v", target, ok)
	}
	tun := servers[2]
	if got := strings.Join(tun.Instances(), ","); got != "p1,bot" {
		t.Fatalf("instances %q", got)
	}
	if target, ok := tun.APITarget("p1"); !ok || target.Instance != "VEAF Private 1" {
		t.Fatalf("renamed instance: %+v %v", target, ok)
	}
	if target, _ := tun.APITarget("bot"); target.Node != "dcs-veaf-org" {
		t.Fatalf("bot = %+v", target)
	}
	if _, ok := tun.APITarget("private2"); ok {
		t.Fatal("`logs:` narrows: an unlisted log is not this server's")
	}
}

func TestParseAPIServersRejections(t *testing.T) {
	cases := map[string]string{
		"host and api":     "servers:\n  a:\n    host: h\n    user: u\n    api: {url: 'https://h', api_key_file: k}\n",
		"no url":           "servers:\n  a:\n    api: {api_key_file: k}\n",
		"no key file":      "servers:\n  a:\n    api: {url: 'https://h'}\n",
		"http to a remote": "servers:\n  a:\n    api: {url: 'http://dcs.veaf.org', api_key_file: k}\n",
		"not http":         "servers:\n  a:\n    api: {url: 'ftp://h', api_key_file: k}\n",
		"api not a map":    "servers:\n  a:\n    api: https://h\n",
		"log both":         "servers:\n  a:\n    api: {url: 'https://h', api_key_file: k}\n    logs: {x: {instance: i, node: n}}\n",
		"log neither":      "servers:\n  a:\n    api: {url: 'https://h', api_key_file: k}\n    logs: {x: {}}\n",
		"log a path":       "servers:\n  a:\n    api: {url: 'https://h', api_key_file: k}\n    logs: {x: 'C:\\dcs.log'}\n",
	}
	for name, doc := range cases {
		_, err := ParseServers([]byte(doc))
		if err == nil {
			t.Errorf("%s: accepted, want an error", name)
			continue
		}
		if name == "host and api" && !strings.Contains(err.Error(), "either") {
			t.Errorf("host and api: %v does not say which", err)
		}
	}
	for _, url := range []string{"http://127.0.0.1:9876", "http://localhost:9876/api", "http://[::1]:9876"} {
		if _, err := ParseServers([]byte("servers:\n  a:\n    api: {url: '" + url + "', api_key_file: k}\n")); err != nil {
			t.Errorf("%s through a tunnel: %v", url, err)
		}
	}
}
