package sshlog

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const aliasConfig = `# my settings
lang: fr
log_aliases:
  'C:\Saved Games\DCS\Logs\dcs.log': Local   # my game
servers:
  veaf:            # SSH
    host: dcs.veaf.org
    user: veaf
    logs: {private1: 'C:/x/dcs.log'}
    aliases: {private1: P1 SSH}
  veaf-api:
    api: {url: 'https://dcs.veaf.org/serverapi', api_key_file: k}
`

func TestParseAliases(t *testing.T) {
	servers, err := ParseServers([]byte(aliasConfig))
	if err != nil {
		t.Fatal(err)
	}
	if servers[0].Aliases["private1"] != "P1 SSH" || len(servers[1].Aliases) != 0 {
		t.Fatalf("aliases = %v / %v", servers[0].Aliases, servers[1].Aliases)
	}
	local, err := ParseLocalAliases([]byte(aliasConfig))
	if err != nil || local[`C:\Saved Games\DCS\Logs\dcs.log`] != "Local" {
		t.Fatalf("local = %v, %v", local, err)
	}
	if _, err := ParseServers([]byte("servers:\n  a:\n    api: {url: 'https://h', api_key_file: k}\n    aliases: [x]\n")); err == nil {
		t.Error("aliases must be a mapping")
	}
}

func TestSetAliasKeepsTheRestOfTheFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "veafmct.yaml")
	os.WriteFile(path, []byte(aliasConfig), 0o600)
	if err := SetAlias(path, "veaf-api", "VEAF (www.veaf.org) [fr] - Privé 1", "Privé 1 API"); err != nil {
		t.Fatal(err)
	}
	if err := SetAlias(path, "veaf", "private1", ""); err != nil { // removed
		t.Fatal(err)
	}
	if err := SetLocalAlias(path, `D:\logs\other.log`, "Other"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	text := string(data)
	for _, keep := range []string{"# my settings", "lang: fr", "# my game", "# SSH", "host: dcs.veaf.org", "api_key_file: k"} {
		if !strings.Contains(text, keep) {
			t.Errorf("%q lost:\n%s", keep, text)
		}
	}
	if strings.Contains(text, "\r") {
		t.Error("CRLF written")
	}
	servers, err := ParseServers(data)
	if err != nil {
		t.Fatal(err)
	}
	if servers[1].Aliases["VEAF (www.veaf.org) [fr] - Privé 1"] != "Privé 1 API" {
		t.Errorf("alias not written:\n%s", text)
	}
	if _, ok := servers[0].Aliases["private1"]; ok {
		t.Errorf("alias not removed:\n%s", text)
	}
	local, _ := ParseLocalAliases(data)
	if local[`D:\logs\other.log`] != "Other" || local[`C:\Saved Games\DCS\Logs\dcs.log`] != "Local" {
		t.Errorf("local = %v", local)
	}
}

func TestSetAliasCreatesTheFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "veafmct.yaml")
	if err := SetLocalAlias(path, `C:\dcs.log`, "Mine"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if local, _ := ParseLocalAliases(data); local[`C:\dcs.log`] != "Mine" {
		t.Fatalf("%s", data)
	}
	if err := SetAlias(path, "gone", "x", "y"); err == nil {
		t.Error("a server absent from the configuration cannot get an alias")
	}
}
