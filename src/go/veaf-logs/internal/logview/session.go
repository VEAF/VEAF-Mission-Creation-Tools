package logview

import (
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// Session (session.py): the open files and the current tab, the filters in
// force, the profile, the font, the panels, the window's place. Written in the
// Python viewer's own file and format, so either viewer picks up where the
// other left off.

const sessionVersion = 2

// OpenFile is one tab of the session. A remote one (`server/instance`) is
// kept and reopened when the remote journals arrive (J4).
type OpenFile struct {
	Path          string  `json:"path"`
	ArchiveMember *string `json:"archive_member"`
	Remote        *string `json:"remote"`
}

// WindowPlace is the Go viewer's window position. The Python's `geometry` is
// Qt's own blob, kept untouched for it.
type WindowPlace struct {
	X, Y, Width, Height int
	Maximized           bool
}

// Session is session.json.
type Session struct {
	Files          []OpenFile      `json:"files"`
	Active         int             `json:"active"`
	Profile        string          `json:"profile"`
	Filters        json.RawMessage `json:"filters"`
	Geometry       *string         `json:"geometry"`
	FontFamily     string          `json:"font_family"`
	FontSize       int             `json:"font_size"`
	DetailVisible  bool            `json:"detail_visible"`
	FiltersVisible bool            `json:"filters_visible"`
	// GoWindow is ignored by the Python, which drops it when it saves.
	GoWindow *WindowPlace `json:"go_window,omitempty"`
	Version  int          `json:"version"`
}

// NewSession is a blank session: the defaults of session.py.
func NewSession() Session {
	return Session{FontFamily: DefaultFontFamily, FontSize: DefaultFontSize, DetailVisible: true, FiltersVisible: true, Filters: json.RawMessage("{}")}
}

// SessionPath is the shared file.
func SessionPath() string { return filepath.Join(ConfigDir(), "session.json") }

// LoadSession reads a session; an absent, unreadable or other-version file is
// a blank session rather than no start. Unknown keys are ignored, missing ones
// take their default — adding a field needs no new version.
func LoadSession(path string) Session {
	s := NewSession()
	raw, err := os.ReadFile(path)
	if err != nil {
		return s
	}
	var probe struct {
		Version int `json:"version"`
	}
	if json.Unmarshal(raw, &probe) != nil || probe.Version != sessionVersion {
		return s
	}
	if json.Unmarshal(raw, &s) != nil {
		return NewSession()
	}
	s.FontSize = ClampFontSize(s.FontSize)
	if s.FontFamily == "" {
		s.FontFamily = DefaultFontFamily
	}
	return s
}

// Save writes the session atomically.
func (s Session) Save(path string) error {
	s.Version = sessionVersion
	if len(s.Filters) == 0 {
		s.Filters = json.RawMessage("{}")
	}
	return writeJSONAtomic(path, s)
}

// FilterSet reads the session's filters; corrupted ones are no filters.
func (s Session) FilterSet() logcore.FilterSet {
	var f logcore.FilterSet
	if len(s.Filters) == 0 || json.Unmarshal(s.Filters, &f) != nil {
		return logcore.NewFilterSet()
	}
	return f
}

// SetFilterSet stores the filters in force.
func (s *Session) SetFilterSet(f logcore.FilterSet) {
	if raw, err := json.Marshal(f); err == nil {
		s.Filters = raw
	}
}

// ExistingFiles drops the local files gone since the last session; a remote
// one is kept: the connection will tell whether it still exists.
func (s Session) ExistingFiles() []OpenFile {
	var out []OpenFile
	for _, f := range s.Files {
		if f.Remote != nil {
			out = append(out, f)
			continue
		}
		if _, err := os.Stat(f.Path); err == nil {
			out = append(out, f)
		}
	}
	return out
}
