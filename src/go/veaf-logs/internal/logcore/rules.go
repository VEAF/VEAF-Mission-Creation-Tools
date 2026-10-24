// Package logcore is the UI-free core of veaf-logs: the rule catalogue, the
// header formats and the compact index of a journal. It is a port of the
// Python `veaf_logs` package (rules, parser, store, buffer); the Python code
// is the reference and the parity test (parity_test.go) is what keeps them equal.
package logcore

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
)

// Native source: a DCS subsystem that is not in the catalogue's `sources`.
const (
	NativeSource = "dcs"
	NativeLabel  = "DCS"
	NativeColor  = "#8b949e"
)

// Levels, in the order of the Python LEVELS tuple (the index is stored in the index).
var Levels = []string{"ALERT", "ERROR", "ERROR_ONCE", "WARNING", "INFO", "DEBUG", "TRACE", "UNKNOWN"}

var levelIndex = func() map[string]uint8 {
	m := make(map[string]uint8, len(Levels))
	for i, name := range Levels {
		m[name] = uint8(i)
	}
	return m
}()

// MaxNoiseFamilies is imposed by the 64-bit mask.
const MaxNoiseFamilies = 64

// Source identifies the emitter of a line (a Lua script or a DCS subsystem).
type Source struct {
	ID, Label, Color string
	Formats          []string
	pattern          *pattern // nil for a source bound to header formats
	levelGroup       string
	levelMap         map[string]string
	modulePattern    *regexp.Regexp
}

// NoiseFamily is a family of noisy lines that can be hidden.
type NoiseFamily struct {
	ID, Label, Help string
	DefaultHidden   bool
	OnMessage       bool
	Formats         []string
	pattern         *pattern
}

// LevelStyle is the colour of a level.
type LevelStyle struct {
	Color      string
	Background string
	Weight     int
	Order      int
}

// Rules is the loaded catalogue with its patterns already compiled.
type Rules struct {
	Sources []Source
	Noise   []NoiseFamily
	Levels  map[string]LevelStyle
}

type rawRules struct {
	Sources []struct {
		ID            string            `json:"id"`
		Label         string            `json:"label"`
		Color         string            `json:"color"`
		Match         *string           `json:"match"`
		LevelGroup    json.RawMessage   `json:"level_group"`
		LevelMap      map[string]string `json:"level_map"`
		ModulePattern string            `json:"module_pattern"`
		Formats       []string          `json:"formats"`
	} `json:"sources"`
	Noise []struct {
		ID            string   `json:"id"`
		Label         string   `json:"label"`
		Help          string   `json:"help"`
		Match         string   `json:"match"`
		Regex         *bool    `json:"regex"`
		DefaultHidden bool     `json:"default_hidden"`
		OnMessage     bool     `json:"on_message"`
		Formats       []string `json:"formats"`
	} `json:"noise"`
	Levels map[string]struct {
		Color      string  `json:"color"`
		Background *string `json:"background"`
		Weight     *int    `json:"weight"`
		Order      *int    `json:"order"`
	} `json:"levels"`
}

// LoadRules reads and compiles a `rules.json` (the Python one, unchanged).
func LoadRules(path string) (*Rules, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseRules(data)
}

// ParseRules compiles a catalogue from its JSON text.
func ParseRules(data []byte) (*Rules, error) {
	var raw rawRules
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("rules: %w", err)
	}
	r := &Rules{Levels: map[string]LevelStyle{}}
	for _, s := range raw.Sources {
		src := Source{ID: s.ID, Label: s.Label, Color: s.Color, levelMap: s.LevelMap, Formats: s.Formats}
		if s.Match != nil {
			re, err := newPattern(*s.Match)
			if err != nil {
				return nil, fmt.Errorf("source %s: %w", s.ID, err)
			}
			src.pattern = re
		}
		if len(s.LevelGroup) > 0 && string(s.LevelGroup) != "null" {
			var name string
			if err := json.Unmarshal(s.LevelGroup, &name); err != nil {
				return nil, fmt.Errorf("source %s: level_group must be a group name", s.ID)
			}
			src.levelGroup = name
		}
		if s.ModulePattern != "" {
			re, err := regexp.Compile(`\A(?:` + s.ModulePattern + `)`)
			if err != nil {
				return nil, fmt.Errorf("source %s module: %w", s.ID, err)
			}
			src.modulePattern = re
		}
		r.Sources = append(r.Sources, src)
	}
	for _, n := range raw.Noise {
		pattern := n.Match
		if n.Regex != nil && !*n.Regex {
			pattern = regexp.QuoteMeta(pattern)
		}
		re, err := newPattern(pattern)
		if err != nil {
			return nil, fmt.Errorf("noise %s: %w", n.ID, err)
		}
		r.Noise = append(r.Noise, NoiseFamily{ID: n.ID, Label: n.Label, Help: n.Help, pattern: re,
			DefaultHidden: n.DefaultHidden, OnMessage: n.OnMessage, Formats: n.Formats})
	}
	if len(r.Noise) > MaxNoiseFamilies {
		return nil, fmt.Errorf("%d noise families: the mask holds %d", len(r.Noise), MaxNoiseFamilies)
	}
	for name, l := range raw.Levels {
		st := LevelStyle{Color: l.Color, Weight: 400, Order: 99}
		if l.Background != nil {
			st.Background = *l.Background
		}
		if l.Weight != nil {
			st.Weight = *l.Weight
		}
		if l.Order != nil {
			st.Order = *l.Order
		}
		r.Levels[name] = st
	}
	return r, nil
}

// LevelStyle returns the style of a level, grey when unknown.
func (r *Rules) LevelStyle(level string) LevelStyle {
	if s, ok := r.Levels[level]; ok {
		return s
	}
	return LevelStyle{Color: NativeColor, Weight: 400, Order: 99}
}

// SourceColor returns the colour of a source id.
func (r *Rules) SourceColor(id string) string {
	for _, s := range r.Sources {
		if s.ID == id {
			return s.Color
		}
	}
	return NativeColor
}

func contains(list []string, id string) bool {
	for _, v := range list {
		if v == id {
			return true
		}
	}
	return false
}

//go:embed rules.json
var embeddedRules []byte

// DefaultRules loads the catalogue embedded in the executable. rules.json here
// is a copy of the Python one, kept identical by TestEmbeddedRulesAreThePythonOnes.
func DefaultRules() (*Rules, error) { return ParseRules(embeddedRules) }
