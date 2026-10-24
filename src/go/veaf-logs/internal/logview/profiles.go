package logview

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// Profiles (profiles.py): named filter sets. Three are built in and can be
// neither changed nor deleted; the user's live in the Python viewer's own
// file, in its format, so both viewers share them.

const (
	profilesVersion = 1
	// DefaultProfile is the unnamed entry: the filters in force.
	DefaultProfile = "Session courante"
)

// ConfigDir is where both viewers keep their files: %APPDATA%\veaf_logs, ~/.config elsewhere.
func ConfigDir() string {
	base := os.Getenv("APPDATA")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "veaf_logs")
}

// BuiltinProfileNames are the built-in profiles, in their order.
var BuiltinProfileNames = []string{"Tout", "Lecture (sans le bruit ED)", "Diagnostic (erreurs + contexte)"}

// BuiltinProfiles computes the built-in profiles from the catalogue.
func BuiltinProfiles(rules *logcore.Rules) map[string]logcore.FilterSet {
	hidden := map[string]logcore.State{}
	for _, f := range rules.Noise {
		if f.DefaultHidden {
			hidden[f.ID] = logcore.StateOff
		}
	}
	copyStates := func() map[string]logcore.State {
		out := make(map[string]logcore.State, len(hidden))
		for k, v := range hidden {
			out[k] = v
		}
		return out
	}
	all := logcore.NewFilterSet()
	reading := logcore.NewFilterSet()
	reading.Noise = copyStates()
	// Keep what calls for action, with a few lines around to understand it.
	diagnostic := logcore.NewFilterSet()
	diagnostic.Levels = map[string]logcore.State{"INFO": logcore.StateContext, "DEBUG": logcore.StateContext, "TRACE": logcore.StateContext}
	diagnostic.Noise = copyStates()
	diagnostic.ContextLines = 3
	return map[string]logcore.FilterSet{BuiltinProfileNames[0]: all, BuiltinProfileNames[1]: reading, BuiltinProfileNames[2]: diagnostic}
}

// ProfileStore holds the built-in and the user's profiles in one namespace.
type ProfileStore struct {
	Path    string
	builtin map[string]logcore.FilterSet
	user    map[string]logcore.FilterSet
}

// NewProfileStore loads the user's profiles; path "" is the shared file.
func NewProfileStore(rules *logcore.Rules, path string) *ProfileStore {
	if path == "" {
		path = filepath.Join(ConfigDir(), "profiles.json")
	}
	s := &ProfileStore{Path: path, builtin: BuiltinProfiles(rules), user: map[string]logcore.FilterSet{}}
	s.load()
	return s
}

// Names lists the built-in profiles first, then the user's alphabetically.
func (s *ProfileStore) Names() []string {
	users := make([]string, 0, len(s.user))
	for name := range s.user {
		users = append(users, name)
	}
	sort.Strings(users)
	return append(append([]string(nil), BuiltinProfileNames...), users...)
}

// IsBuiltin tells whether a profile is built in.
func (s *ProfileStore) IsBuiltin(name string) bool {
	_, ok := s.builtin[name]
	return ok
}

// Get returns a copy: editing the filters in force never rewrites the profile they came from.
func (s *ProfileStore) Get(name string) (logcore.FilterSet, bool) {
	if f, ok := s.builtin[name]; ok {
		return f.Copy(), true
	}
	if f, ok := s.user[name]; ok {
		return f.Copy(), true
	}
	return logcore.FilterSet{}, false
}

// Save saves or replaces a user profile.
func (s *ProfileStore) Save(name string, f logcore.FilterSet) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return errors.New("un profil doit avoir un nom")
	}
	if s.IsBuiltin(name) {
		return fmt.Errorf("« %s » est un profil fourni, choisis un autre nom", name)
	}
	s.user[name] = f.Copy()
	return s.write()
}

// Delete deletes a user profile.
func (s *ProfileStore) Delete(name string) error {
	if s.IsBuiltin(name) {
		return fmt.Errorf("« %s » est un profil fourni, il ne peut pas être supprimé", name)
	}
	delete(s.user, name)
	return s.write()
}

func (s *ProfileStore) load() {
	raw, err := os.ReadFile(s.Path)
	if err != nil {
		return // absent or unreadable: the built-in profiles alone, rather than no start
	}
	var payload struct {
		Version  int                        `json:"version"`
		Profiles map[string]json.RawMessage `json:"profiles"`
	}
	if json.Unmarshal(raw, &payload) != nil || payload.Version != profilesVersion {
		return
	}
	for name, data := range payload.Profiles {
		var f logcore.FilterSet
		if s.IsBuiltin(name) || json.Unmarshal(data, &f) != nil {
			continue
		}
		s.user[name] = f
	}
}

func (s *ProfileStore) write() error {
	payload := struct {
		Version  int                          `json:"version"`
		Profiles map[string]logcore.FilterSet `json:"profiles"`
	}{profilesVersion, s.user}
	return writeJSONAtomic(s.Path, payload)
}

// writeJSONAtomic writes through a temporary file: a file cut by a crash would stop the next start.
func writeJSONAtomic(path string, v any) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := strings.TrimSuffix(path, filepath.Ext(path)) + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
