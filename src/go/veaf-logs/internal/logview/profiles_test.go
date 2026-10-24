package logview

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

func TestBuiltinProfiles(t *testing.T) {
	r := rules(t)
	s := NewProfileStore(r, filepath.Join(t.TempDir(), "profiles.json"))
	if !reflect.DeepEqual(s.Names(), BuiltinProfileNames) {
		t.Fatalf("names %v", s.Names())
	}
	all, _ := s.Get("Tout")
	if !all.IsEmpty() {
		t.Error("Tout filters nothing")
	}
	reading, _ := s.Get("Lecture (sans le bruit ED)")
	hidden := 0
	for _, f := range r.Noise {
		if f.DefaultHidden {
			hidden++
			if reading.Noise[f.ID] != logcore.StateOff {
				t.Errorf("Lecture leaves %s shown", f.ID)
			}
		}
	}
	if len(reading.Noise) != hidden {
		t.Errorf("Lecture hides %d families, the catalogue marks %d", len(reading.Noise), hidden)
	}
	diagnostic, _ := s.Get("Diagnostic (erreurs + contexte)")
	if diagnostic.Levels["INFO"] != logcore.StateContext || diagnostic.ContextLines != 3 {
		t.Errorf("Diagnostic: %+v", diagnostic)
	}
}

func TestProfilesSaveDeleteAndCopies(t *testing.T) {
	path := filepath.Join(t.TempDir(), "profiles.json")
	s := NewProfileStore(rules(t), path)
	if err := s.Save("Tout", logcore.NewFilterSet()); err == nil {
		t.Error("a built-in name is refused")
	}
	if err := s.Save("  ", logcore.NewFilterSet()); err == nil {
		t.Error("an empty name is refused")
	}
	if err := s.Delete("Tout"); err == nil {
		t.Error("a built-in profile cannot be deleted")
	}
	f := logcore.NewFilterSet()
	f.Levels = map[string]logcore.State{"DEBUG": logcore.StateOff}
	if err := s.Save("  Mes erreurs ", f); err != nil {
		t.Fatal(err)
	}
	got, ok := s.Get("Mes erreurs")
	if !ok || got.Levels["DEBUG"] != logcore.StateOff {
		t.Fatalf("saved under its trimmed name: %v %+v", ok, got)
	}
	got.Levels["DEBUG"] = logcore.StateContext
	again, _ := s.Get("Mes erreurs")
	if again.Levels["DEBUG"] != logcore.StateOff {
		t.Error("Get returns a copy")
	}
	reread := NewProfileStore(rules(t), path)
	if names := reread.Names(); names[len(names)-1] != "Mes erreurs" {
		t.Errorf("reread: %v", names)
	}
	if err := reread.Delete("Mes erreurs"); err != nil {
		t.Fatal(err)
	}
	if len(NewProfileStore(rules(t), path).Names()) != 3 {
		t.Error("deleted")
	}
}

// A profiles.json as the Python writes it (json.dumps(indent=2), to_dict),
// with a profile shadowing a built-in name, which is ignored.
const pythonProfiles = `{
  "version": 1,
  "profiles": {
    "Zut": {"levels": {"DEBUG": "off"}, "sources": {}, "noise": {"taxiroad": "context"}, "text_filters": [{"pattern": "VEAF", "mode": "glob", "case_sensitive": false, "invert": true, "enabled": true, "context_lines": 2}], "context_lines": 4, "context_spans": {"levels:INFO": 9}, "search_context_lines": 1},
    "Tout": {"levels": {"INFO": "off"}}
  }
}`

func TestReadsThePythonFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "profiles.json")
	os.WriteFile(path, []byte(pythonProfiles), 0o644)
	s := NewProfileStore(rules(t), path)
	zut, ok := s.Get("Zut")
	if !ok || zut.Levels["DEBUG"] != logcore.StateOff || zut.Noise["taxiroad"] != logcore.StateContext ||
		zut.ContextLines != 4 || zut.SpanFor("levels", "INFO") != 9 || zut.SearchContextLines != 1 ||
		len(zut.TextFilters) != 1 || zut.TextFilters[0].Mode != logcore.ModeGlob || !zut.TextFilters[0].Invert {
		t.Fatalf("Zut: %+v", zut)
	}
	if tout, _ := s.Get("Tout"); !tout.IsEmpty() {
		t.Error("a user profile cannot shadow a built-in one")
	}
	// Written back, it stays the Python's format.
	s.Save("Autre", logcore.NewFilterSet())
	var back struct {
		Version  int                        `json:"version"`
		Profiles map[string]json.RawMessage `json:"profiles"`
	}
	raw, _ := os.ReadFile(path)
	if err := json.Unmarshal(raw, &back); err != nil || back.Version != 1 || len(back.Profiles) != 2 {
		t.Fatalf("written back: %v %s", err, raw)
	}
}

func TestUnreadableOrOtherVersionIsBuiltinOnly(t *testing.T) {
	for _, content := range []string{"{not json", `{"version": 2, "profiles": {"x": {}}}`} {
		path := filepath.Join(t.TempDir(), "profiles.json")
		os.WriteFile(path, []byte(content), 0o644)
		if n := len(NewProfileStore(rules(t), path).Names()); n != 3 {
			t.Errorf("%q: %d profiles", content, n)
		}
	}
}
