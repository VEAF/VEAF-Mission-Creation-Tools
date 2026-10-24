package analysis

import (
	"fmt"
	"sort"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// The catalogue layer (`veaf_logs.catalogue`): what rules.json already knows,
// its wording reproduced as it stands, and silence reported as silence.

const (
	kindNoise     = "noise"
	kindSource    = "source"
	kindSubsystem = "subsystem"

	nothingRecognised = "Le catalogue ne reconnaît aucun motif dans cet extrait."
	headingKnown      = "Motifs connus (texte du catalogue, tel quel) :"
	headingEmitters   = "Émetteurs reconnus :"
)

// CatalogueMatch is one catalogue entry the excerpt matched, with how often.
type CatalogueMatch struct {
	ID, Label, Help, Kind string
	Count                 int
}

// Render is the match as the catalogue states it, plus its count.
func (m CatalogueMatch) Render() string {
	head := fmt.Sprintf("%s (%s) ×%d", m.Label, m.ID, m.Count)
	if m.Help != "" {
		return "- " + head + " : " + m.Help
	}
	return "- " + head
}

// WorkerMatch is one match as the Worker's /analyze route reads it.
type WorkerMatch struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Help  string `json:"help"`
	Count int    `json:"count"`
}

// isCatalogued: a noise family matched the record, or a source recognised by a
// pattern of its own emitted it. The log a line was read from says nothing about it.
func isCatalogued(rules *logcore.Rules, e ExcerptEntry) bool {
	if len(e.Noise) > 0 {
		return true
	}
	if e.SourceID == logcore.NativeSource {
		return false
	}
	for _, s := range rules.Sources {
		if s.ID == e.SourceID && s.HasPattern() {
			return true
		}
	}
	return false
}

// MatchCatalogue collects every catalogue entry the excerpt matched, most frequent first.
func MatchCatalogue(rules *logcore.Rules, x Excerpt) []CatalogueMatch {
	noise, sources, families := map[string]int{}, map[string]int{}, map[string]int{}
	for _, e := range x.Entries {
		for _, f := range e.Noise {
			noise[f]++
		}
		if e.SourceID != "" {
			sources[e.SourceID]++
		}
		if f := rules.SubsystemFamily(e.Subsystem); f != "" {
			families[f]++
		}
	}
	var out []CatalogueMatch
	for _, f := range rules.Noise {
		if n, ok := noise[f.ID]; ok {
			out = append(out, CatalogueMatch{ID: f.ID, Label: f.Label, Help: f.Help, Kind: kindNoise, Count: n})
		}
	}
	labels := rules.SourceLabels()
	for id, n := range sources {
		label, ok := labels[id]
		if !ok {
			label = id
		}
		out = append(out, CatalogueMatch{ID: id, Label: label, Kind: kindSource, Count: n})
	}
	for f, n := range families {
		out = append(out, CatalogueMatch{ID: f, Label: f, Kind: kindSubsystem, Count: n})
	}
	sort.Slice(out, func(i, j int) bool {
		a, b := out[i], out[j]
		if a.Count != b.Count {
			return a.Count > b.Count
		}
		if a.Kind != b.Kind {
			return a.Kind < b.Kind
		}
		return a.ID < b.ID
	})
	return out
}

// Uncatalogued are the records the catalogue says nothing about, in log order.
func Uncatalogued(rules *logcore.Rules, x Excerpt) []ExcerptEntry {
	var out []ExcerptEntry
	for _, e := range x.Entries {
		if !isCatalogued(rules, e) {
			out = append(out, e)
		}
	}
	return out
}

// RenderCatalogue renders the verified text, grouped by what it is; an empty
// catalogue answer says so rather than leaving a blank section.
func RenderCatalogue(matches []CatalogueMatch) string {
	var explained, emitters []string
	for _, m := range matches {
		if m.Kind == kindNoise {
			explained = append(explained, m.Render())
		} else {
			emitters = append(emitters, m.Render())
		}
	}
	var blocks []string
	if len(explained) > 0 {
		blocks = append(blocks, headingKnown+"\n"+strings.Join(explained, "\n"))
	}
	if len(emitters) > 0 {
		blocks = append(blocks, headingEmitters+"\n"+strings.Join(emitters, "\n"))
	}
	if len(blocks) == 0 {
		return nothingRecognised
	}
	return strings.Join(blocks, "\n\n")
}

// ToWorkerMatches keeps only what the catalogue explains: an emitter with no
// help invites the model to fill the blank itself.
func ToWorkerMatches(matches []CatalogueMatch) []WorkerMatch {
	out := []WorkerMatch{}
	for _, m := range matches {
		if m.Kind == kindNoise {
			out = append(out, WorkerMatch{ID: m.ID, Label: m.Label, Help: m.Help, Count: m.Count})
		}
	}
	return out
}
