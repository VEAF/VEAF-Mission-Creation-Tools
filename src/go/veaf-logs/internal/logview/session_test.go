package logview

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// A session.json as the Python writes it, with a remote tab and Qt's geometry.
func pythonSession(t *testing.T, local string) string {
	t.Helper()
	escaped, _ := json.Marshal(local)
	return `{
  "files": [
    {"path": ` + string(escaped) + `, "archive_member": null, "remote": null},
    {"path": "/home/dcs/Saved Games/DCS/Logs/dcs.log", "archive_member": null, "remote": "veaf/public1"},
    {"path": "C:/gone/dcs.log", "archive_member": null, "remote": null}
  ],
  "active": 1,
  "profile": "Session courante",
  "filters": {"levels": {"DEBUG": "off"}, "search_context_lines": 2},
  "geometry": "AdnQywADAAAAAAKdAAAA",
  "font_family": "Consolas",
  "font_size": 99,
  "detail_visible": false,
  "filters_visible": true,
  "unknown_key": 1,
  "version": 2
}`
}

func TestReadsThePythonSession(t *testing.T) {
	dir := t.TempDir()
	local := filepath.Join(dir, "dcs.log")
	os.WriteFile(local, []byte("x\n"), 0o644)
	path := filepath.Join(dir, "session.json")
	os.WriteFile(path, []byte(pythonSession(t, local)), 0o644)

	s := LoadSession(path)
	if s.Active != 1 || s.FontFamily != "Consolas" || s.FontSize != MaxFontSize || s.DetailVisible || !s.FiltersVisible {
		t.Fatalf("session: %+v", s)
	}
	if f := s.FilterSet(); f.Levels["DEBUG"] != logcore.StateOff || f.SearchContextLines != 2 {
		t.Errorf("filters: %+v", f)
	}
	files := s.ExistingFiles()
	if len(files) != 2 || files[0].Path != local || files[1].Remote == nil || *files[1].Remote != "veaf/public1" {
		t.Fatalf("existing files (the gone one dropped, the remote kept): %+v", files)
	}

	// Saved back by Go: the Python's geometry and the remote tab survive.
	s.Files = files
	s.GoWindow = &WindowPlace{X: 10, Y: 20, Width: 800, Height: 600}
	if err := s.Save(path); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	for _, want := range []string{`"geometry": "AdnQywADAAAAAAKdAAAA"`, `"remote": "veaf/public1"`, `"version": 2`, `"go_window"`} {
		if !strings.Contains(string(raw), want) {
			t.Errorf("saved session lacks %s:\n%s", want, raw)
		}
	}
	again := LoadSession(path)
	if again.GoWindow == nil || again.GoWindow.Width != 800 || len(again.Files) != 2 {
		t.Errorf("reread: %+v", again)
	}
}

func TestBlankSessionWhenUnusable(t *testing.T) {
	dir := t.TempDir()
	for name, content := range map[string]string{"absent": "", "broken": "{", "other version": `{"version": 1, "font_size": 20}`} {
		path := filepath.Join(dir, name+".json")
		if content != "" {
			os.WriteFile(path, []byte(content), 0o644)
		}
		s := LoadSession(path)
		if s.FontSize != DefaultFontSize || !s.DetailVisible || !s.FiltersVisible || len(s.Files) != 0 {
			t.Errorf("%s: %+v", name, s)
		}
	}
}

func TestCorruptedFiltersAreNoFilters(t *testing.T) {
	s := NewSession()
	s.Filters = json.RawMessage(`{"context_lines": "beaucoup"}`)
	if f := s.FilterSet(); !f.IsEmpty() || f.ContextLines != logcore.DefaultContextLines {
		t.Errorf("%+v", f)
	}
	f := logcore.NewFilterSet()
	f.Sources = map[string]logcore.State{"veaf": logcore.StateOff}
	s.SetFilterSet(f)
	if got := s.FilterSet(); got.Sources["veaf"] != logcore.StateOff {
		t.Error("set then read")
	}
}
