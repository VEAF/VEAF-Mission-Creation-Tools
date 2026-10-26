package sshlog

import (
	"fmt"
	"net/url"
	"strings"

	"gopkg.in/yaml.v3"
)

// A server read through DCSServerBot's RestAPI rather than SSH
// (FEAT-VEAF-LOGS-REST-API): no account on the machine, an API key, and the
// logs found by asking the API. The HTTP side is internal/apilog.

// BotLog is the name of the bot's own log among a server's discovered logs.
const BotLog = "bot"

// API is how to reach a server's RestAPI. The key is read from KeyFile when a
// log is opened, and kept nowhere else.
type API struct {
	URL     string // with the RestAPI's prefix, if it has one
	KeyFile string
	// Logs narrows and renames what is discovered; nil: everything the API lists.
	Logs map[string]APILog
}

// APILog is one log of the API: a server's DCS log (Instance, the server's
// name as the bot knows it), or a node's bot log (Instance empty; Node empty
// is the node that serves the API).
type APILog struct {
	Instance string
	Node     string
}

// APITarget is the log behind a name of the server's: one of `logs:`, or
// without it a discovered one — the bot log, or a server's name.
func (s Server) APITarget(name string) (APILog, bool) {
	if s.API == nil {
		return APILog{}, false
	}
	if s.API.Logs != nil {
		l, ok := s.API.Logs[name]
		return l, ok
	}
	if name == BotLog {
		return APILog{}, true
	}
	return APILog{Instance: name}, name != ""
}

func mappingHas(n *yaml.Node, key string) bool {
	for i := 0; i+1 < len(n.Content); i += 2 {
		if n.Content[i].Value == key {
			return true
		}
	}
	return false
}

func parseAPIServer(name string, n *yaml.Node) (Server, error) {
	s := Server{Name: name, API: &API{}}
	for i := 0; i+1 < len(n.Content); i += 2 {
		key, val := n.Content[i].Value, n.Content[i+1]
		switch key {
		case "host", "user", "port", "key":
			return Server{}, fmt.Errorf("servers.%s: either `host` (SSH) or `api` (RestAPI), not both", name)
		case "api":
			if val.Kind != yaml.MappingNode {
				return Server{}, fmt.Errorf("servers.%s.api: expected a mapping (url, api_key_file)", name)
			}
			for j := 0; j+1 < len(val.Content); j += 2 {
				switch val.Content[j].Value {
				case "url":
					s.API.URL = strings.TrimRight(strings.TrimSpace(val.Content[j+1].Value), "/")
				case "api_key_file":
					s.API.KeyFile = expandHome(strings.TrimSpace(val.Content[j+1].Value))
				}
			}
		case "logs":
			if val.Kind != yaml.MappingNode || len(val.Content) == 0 {
				return Server{}, fmt.Errorf("servers.%s.logs: expected a non-empty mapping of name to {instance: …} or {node: …}", name)
			}
			s.API.Logs = map[string]APILog{}
			for j := 0; j+1 < len(val.Content); j += 2 {
				log, l := val.Content[j].Value, val.Content[j+1]
				var target struct {
					Instance string `yaml:"instance"`
					Node     string `yaml:"node"`
				}
				if l.Kind != yaml.MappingNode || l.Decode(&target) != nil || (target.Instance == "") == (target.Node == "") {
					return Server{}, fmt.Errorf("servers.%s.logs.%s: expected {instance: <server name>} or {node: <node name>}", name, log)
				}
				s.API.Logs[log] = APILog{Instance: target.Instance, Node: target.Node}
				s.logOrder = append(s.logOrder, log)
			}
		}
	}
	if s.API.URL == "" || s.API.KeyFile == "" {
		return Server{}, fmt.Errorf("servers.%s.api: url and api_key_file are required", name)
	}
	if err := checkAPIURL(s.API.URL); err != nil {
		return Server{}, fmt.Errorf("servers.%s.api.url: %w", name, err)
	}
	return s, nil
}

// checkAPIURL wants HTTPS: the key and the logs (player names, IP addresses)
// cross the network. Plain HTTP only to this machine, the end of an SSH tunnel.
func checkAPIURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return fmt.Errorf("%q is not a URL", raw)
	}
	switch u.Scheme {
	case "https":
		return nil
	case "http":
		if h := u.Hostname(); h == "127.0.0.1" || h == "localhost" || h == "::1" {
			return nil
		}
		return fmt.Errorf("%s: plain http only to 127.0.0.1 or localhost (an SSH tunnel), use https", raw)
	}
	return fmt.Errorf("%s: expected an https:// URL", raw)
}
