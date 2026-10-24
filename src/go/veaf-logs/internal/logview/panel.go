package logview

import (
	"fmt"
	"sort"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// The side panel (ui/panels.py), without its widgets: which categories, in
// which order, how a state reads and cycles.

// Category is one row of the side panel.
type Category struct {
	Key, Label string
	Count      int
	Color      string // "" for the default text colour
	Hint       string // the catalogue's help text (noise families)
}

// LevelCategories lists the levels met, in the catalogue's order.
func LevelCategories(rules *logcore.Rules, counts map[string]int) []Category {
	levels := make([]string, 0, len(counts))
	for l := range counts {
		levels = append(levels, l)
	}
	sort.SliceStable(levels, func(i, j int) bool {
		oi, oj := rules.LevelStyle(levels[i]).Order, rules.LevelStyle(levels[j]).Order
		if oi != oj {
			return oi < oj
		}
		return levels[i] < levels[j]
	})
	out := make([]Category, len(levels))
	for i, l := range levels {
		out[i] = Category{Key: l, Label: l, Count: counts[l], Color: rules.LevelStyle(l).Color}
	}
	return out
}

// SourceCategories lists the sources met, the busiest first; equal counts
// keep the order the sources first appeared in, as the Python's dict does.
func SourceCategories(rules *logcore.Rules, counts map[string]int, order []string) []Category {
	labels := map[string]string{logcore.NativeSource: logcore.NativeLabel}
	for _, s := range rules.Sources {
		labels[s.ID] = s.Label
	}
	ids := append([]string(nil), order...)
	sort.SliceStable(ids, func(i, j int) bool { return counts[ids[i]] > counts[ids[j]] })
	out := make([]Category, 0, len(ids))
	for _, id := range ids {
		label, ok := labels[id]
		if !ok {
			label = id
		}
		out = append(out, Category{Key: id, Label: label, Count: counts[id], Color: rules.SourceColor(id)})
	}
	return out
}

// NoiseCategories lists the noise families met, in the catalogue's order. A
// family has no row until met: a DCSServerBot journal would list twenty DCS
// families at zero. Its state lives in the filters and comes back with it.
func NoiseCategories(rules *logcore.Rules, counts map[string]int) []Category {
	var out []Category
	for _, f := range rules.Noise {
		if n := counts[f.ID]; n > 0 {
			out = append(out, Category{Key: f.ID, Label: f.Label, Count: n, Hint: f.Help})
		}
	}
	return out
}

// NextState is the state a click gives: shown, then context, then hidden.
func NextState(s logcore.State) logcore.State {
	switch s {
	case logcore.StateOn, "":
		return logcore.StateContext
	case logcore.StateContext:
		return logcore.StateOff
	}
	return logcore.StateOn
}

// StateMark is a state's glyph.
func StateMark(s logcore.State) string {
	switch s {
	case logcore.StateContext:
		return "◐"
	case logcore.StateOff:
		return "✕"
	}
	return "✓"
}

// StateHint is what a state means, for the tooltip.
func StateHint(s logcore.State) string {
	switch s {
	case logcore.StateContext:
		return "affiché seulement autour des lignes retenues"
	case logcore.StateOff:
		return "masqué"
	}
	return "affiché"
}

// RowText is the text of a category's button.
func RowText(c Category, s logcore.State) string {
	return fmt.Sprintf(" %s  %s  (%d)", StateMark(s), c.Label, c.Count)
}

// RowTooltip is a category's tooltip: its help, then its state.
func RowTooltip(c Category, s logcore.State) string {
	state := "État : " + StateHint(s) + "\nClic : état suivant"
	if c.Hint == "" {
		return state
	}
	return c.Hint + "\n\n" + state
}

// Legend is the panel's first line.
const Legend = "✓ affiché     ◐ contexte     ✕ masqué"

// StateOf is a category's state in a filter set (absent: shown).
func StateOf(f logcore.FilterSet, kind, key string) logcore.State {
	var table map[string]logcore.State
	switch kind {
	case "levels":
		table = f.Levels
	case "sources":
		table = f.Sources
	case "noise":
		table = f.Noise
	}
	if s, ok := table[key]; ok {
		return s
	}
	return logcore.StateOn
}

// SetAll sets every listed category of a kind to one state — the group's
// `tout / contexte / rien`. Categories not listed keep theirs: absent from
// this journal, their state is a choice the filters still carry.
func SetAll(f *logcore.FilterSet, kind string, keys []string, s logcore.State) {
	for _, k := range keys {
		f.SetState(kind, k, s)
	}
}

// SpanSuffix is what a category's span field shows when it follows the common span.
func SpanSuffix(own *int, common int) string {
	if own != nil {
		return ""
	}
	return fmt.Sprintf(" (%d)", common)
}

// SearchContextHint is how the search field's span shows the common value at zero.
func SearchContextHint(common int) string { return fmt.Sprintf("(%d)", common) }
