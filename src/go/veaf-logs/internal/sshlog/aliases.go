package sshlog

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Aliases of the tabs (FEAT-GO-VEAF-LOGS-TABS): a remote log's in its server's
// `aliases:`, a local file's in a top-level `log_aliases:` keyed by its path.
// The window renames a tab by writing them here, the rest of the file kept.

// parseAliases reads an `aliases:` mapping of log name to alias.
func parseAliases(where string, n *yaml.Node) (map[string]string, error) {
	if n.Kind != yaml.MappingNode {
		return nil, fmt.Errorf("%s: expected a mapping of log name to alias", where)
	}
	out := map[string]string{}
	for i := 0; i+1 < len(n.Content); i += 2 {
		if alias := strings.TrimSpace(n.Content[i+1].Value); alias != "" {
			out[n.Content[i].Value] = alias
		}
	}
	return out, nil
}

// ParseLocalAliases reads the `log_aliases:` block: a local file's path to its tab's alias.
func ParseLocalAliases(data []byte) (map[string]string, error) {
	var doc struct {
		Aliases yaml.Node `yaml:"log_aliases"`
	}
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("configuration: %w", err)
	}
	if doc.Aliases.Kind == 0 || doc.Aliases.Tag == "!!null" {
		return map[string]string{}, nil
	}
	return parseAliases("log_aliases", &doc.Aliases)
}

// LoadLocalAliases reads the `log_aliases:` block of the configuration in use.
func LoadLocalAliases(paths ...string) (map[string]string, error) {
	path := FindConfig(paths...)
	if path == "" {
		return map[string]string{}, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseLocalAliases(data)
}

// SetAlias writes a remote log's alias into its server's `aliases:`; an empty
// alias removes it. The server must be in the configuration.
func SetAlias(configPath, server, log, alias string) error {
	return editConfig(configPath, func(root *yaml.Node) error {
		servers := child(root, "servers", false)
		var s *yaml.Node
		if servers != nil {
			s = child(servers, server, false)
		}
		if s == nil {
			return fmt.Errorf("servers.%s is not in %s", server, configPath)
		}
		setEntry(s, "aliases", log, alias)
		return nil
	})
}

// SetLocalAlias writes a local file's alias into `log_aliases:`; an empty alias
// removes it. The file is created when there is none.
func SetLocalAlias(configPath, file, alias string) error {
	return editConfig(configPath, func(root *yaml.Node) error {
		setEntry(root, "log_aliases", file, alias)
		return nil
	})
}

// editConfig applies edit to the configuration's YAML tree and writes it back,
// comments and order kept; a missing file is an empty one.
func editConfig(path string, edit func(root *yaml.Node) error) error {
	data, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	var doc yaml.Node
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	if doc.Kind == 0 {
		doc = yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{{Kind: yaml.MappingNode}}}
	}
	root := doc.Content[0]
	if root.Kind != yaml.MappingNode {
		return fmt.Errorf("%s: expected a mapping at the top", path)
	}
	if err := edit(root); err != nil {
		return err
	}
	var out bytes.Buffer
	enc := yaml.NewEncoder(&out)
	enc.SetIndent(2)
	if err := enc.Encode(&doc); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, out.Bytes(), 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// child is the value of key in mapping m; with create, an empty mapping is added when absent.
func child(m *yaml.Node, key string, create bool) *yaml.Node {
	for i := 0; i+1 < len(m.Content); i += 2 {
		if m.Content[i].Value == key {
			return m.Content[i+1]
		}
	}
	if !create {
		return nil
	}
	v := &yaml.Node{Kind: yaml.MappingNode}
	m.Content = append(m.Content, &yaml.Node{Kind: yaml.ScalarNode, Value: key}, v)
	return v
}

// setEntry sets m[block][key] = value, or removes it when value is empty (and
// the block with it once empty).
func setEntry(m *yaml.Node, block, key, value string) {
	b := child(m, block, value != "")
	if b == nil {
		return
	}
	if b.Kind != yaml.MappingNode { // `block:` written empty
		*b = yaml.Node{Kind: yaml.MappingNode}
	}
	for i := 0; i+1 < len(b.Content); i += 2 {
		if b.Content[i].Value == key {
			if value == "" {
				b.Content = append(b.Content[:i], b.Content[i+2:]...)
				if len(b.Content) == 0 {
					removeKey(m, block)
				}
				return
			}
			b.Content[i+1].Value, b.Content[i+1].Tag, b.Content[i+1].Style = value, "!!str", 0
			return
		}
	}
	if value != "" {
		b.Content = append(b.Content, &yaml.Node{Kind: yaml.ScalarNode, Value: key}, &yaml.Node{Kind: yaml.ScalarNode, Value: value})
	}
}

func removeKey(m *yaml.Node, key string) {
	for i := 0; i+1 < len(m.Content); i += 2 {
		if m.Content[i].Value == key {
			m.Content = append(m.Content[:i], m.Content[i+2:]...)
			return
		}
	}
}
