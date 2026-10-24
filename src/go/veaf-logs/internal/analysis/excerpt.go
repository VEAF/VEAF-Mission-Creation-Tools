package analysis

import (
	"fmt"
	"sort"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// The excerpt (`veaf_logs.excerpt`): what is on screen, bounded, redacted, and
// honest about what was hidden. Lengths are Python's, in code points.

const (
	// DefaultMaxChars is the excerpt's ceiling, header included.
	DefaultMaxChars = 16000

	maxCharsPerLine      = 300
	maxContinuationLines = 8
	truncationMark       = " […]"

	nothingSelected = "(aucune ligne retenue par les filtres courants)"
	nothingAfforded = "(la limite de taille n'a payé aucune ligne : voir le compte ci-dessus)"
)

// severeLevels are the levels whose absence turns a broken session into a clean-looking log.
var severeLevels = map[string]bool{"ALERT": true, "ERROR": true, "ERROR_ONCE": true}

// kindLabels are the three category families, in the header's order.
var kindLabels = []struct{ kind, label string }{
	{"levels", "niveaux"},
	{"sources", "sources"},
	{"noise", "familles de bruit"},
}

// ExcerptEntry is one record, already redacted and capped.
type ExcerptEntry struct {
	Lineno        int
	Timestamp     string
	Level         string
	Source        string // the display label (`VEAF-GRASS`)
	SourceID      string // the catalogue's id (`veaf`, `dcs`)
	Subsystem     string
	Message       string
	Noise         []string
	Continuations []string
}

// Render is the record as the excerpt shows it, continuation lines included.
func (e ExcerptEntry) Render() string {
	ts := e.Timestamp
	if ts == "" {
		ts = "--:--:--"
	}
	head := padRight(ts, 12) + " " + padRight(e.Level, 10) + " " + padRight(e.Source, 12) + " " + e.Message
	lines := []string{capLine(head)}
	for _, l := range e.Continuations {
		lines = append(lines, "    "+capLine(l))
	}
	return strings.Join(lines, "\n")
}

// Excerpt is a bounded, redacted view of a log, plus what is needed to read it honestly.
type Excerpt struct {
	Entries      []ExcerptEntry
	TotalIndexed int
	Selected     int
	Omitted      int
	Excluded     map[string][]string // keys in ✕, by family
	ContextOnly  map[string][]string // keys in ◐, by family
	Searches     []string
}

// HiddenSeverity lists the severe levels the user excluded.
func (x Excerpt) HiddenSeverity() []string {
	var out []string
	for _, l := range x.Excluded["levels"] {
		if severeLevels[l] {
			out = append(out, l)
		}
	}
	return out
}

// headerLines says what this excerpt is, and above all what it is not.
func (x Excerpt) headerLines() []string {
	first := fmt.Sprintf("[veaf-logs] %d entrées sur %d indexées", len(x.Entries), x.TotalIndexed)
	if x.Omitted > 0 {
		first += fmt.Sprintf(" (%d retenues, %d omises par la limite de taille)", x.Selected, x.Omitted)
	}
	lines := []string{first}
	for _, k := range kindLabels {
		if keys := x.Excluded[k.kind]; len(keys) > 0 {
			lines = append(lines, "masqué (✕) — "+k.label+" : "+strings.Join(keys, ", "))
		}
	}
	for _, k := range kindLabels {
		if keys := x.ContextOnly[k.kind]; len(keys) > 0 {
			lines = append(lines, "contexte (◐) — "+k.label+" : "+strings.Join(keys, ", "))
		}
	}
	if len(x.Searches) > 0 {
		lines = append(lines, "recherche : "+strings.Join(x.Searches, " | "))
	}
	if hidden := x.HiddenSeverity(); len(hidden) > 0 {
		lines = append(lines, "ATTENTION : "+strings.Join(hidden, ", ")+" est masqué — l'absence de ces lignes dans cet extrait ne prouve rien.")
	}
	return lines
}

// Rebound is the same excerpt refitted to a tighter ceiling: as many records
// as it pays for — none at all when it pays for none, which a caller must read.
func (x Excerpt) Rebound(maxChars int) Excerpt {
	return bound(x, len(x.Entries), func(i int) ExcerptEntry { return x.Entries[i] }, maxChars, x.Omitted)
}

// Text renders the header, then the records.
func (x Excerpt) Text() string {
	blocks := []string{strings.Join(x.headerLines(), "\n")}
	switch {
	case x.Omitted > 0 && len(x.Entries) > 0:
		body := make([]string, 0, len(x.Entries)+1)
		for _, e := range x.Entries {
			body = append(body, e.Render())
		}
		cut := splitPoint(len(body))
		body = append(body[:cut], append([]string{fmt.Sprintf("… %d entrées omises …", x.Omitted)}, body[cut:]...)...)
		blocks = append(blocks, strings.Join(body, "\n"))
	case len(x.Entries) > 0:
		body := make([]string, 0, len(x.Entries))
		for _, e := range x.Entries {
			body = append(body, e.Render())
		}
		blocks = append(blocks, strings.Join(body, "\n"))
	case x.Omitted > 0:
		blocks = append(blocks, nothingAfforded)
	default:
		blocks = append(blocks, nothingSelected)
	}
	return strings.Join(blocks, "\n")
}

func capLine(line string) string {
	if runeLen(line) <= maxCharsPerLine {
		return line
	}
	return runePrefix(line, maxCharsPerLine) + truncationMark
}

// splitPoint is where the omission marker goes: after the head half.
func splitPoint(count int) int { return (count + 1) / 2 }

// keysInState collects the keys of every family sitting in a state, sorted.
func keysInState(f *logcore.FilterSet, wanted logcore.State) map[string][]string {
	found := map[string][]string{}
	for _, k := range kindLabels {
		var table map[string]logcore.State
		switch k.kind {
		case "levels":
			table = f.Levels
		case "sources":
			table = f.Sources
		case "noise":
			table = f.Noise
		}
		var keys []string
		for key, state := range table {
			if state == wanted {
				keys = append(keys, key)
			}
		}
		if len(keys) > 0 {
			sort.Strings(keys)
			found[k.kind] = keys
		}
	}
	return found
}

// isExcluded tells that a record belongs to a category set to ✕: whatever
// produced the selection, such a record never travels. `noiseOff` tells whether
// any family is set to ✕ at all: when none is, an entry's families need not be
// built — the common case, and a million names saved.
func isExcluded(store *logcore.Store, f *logcore.FilterSet, index int, noiseOff bool) bool {
	if f.Levels[store.LevelOf(index)] == logcore.StateOff {
		return true
	}
	if f.Sources[store.SourceOf(index)] == logcore.StateOff {
		return true
	}
	if !noiseOff {
		return false
	}
	for _, family := range store.NoiseOf(index) {
		if f.Noise[family] == logcore.StateOff {
			return true
		}
	}
	return false
}

func toExcerptEntry(r *Redactor, e logcore.Entry) ExcerptEntry {
	trace := e.Continuation
	if len(trace) > maxContinuationLines {
		dropped := len(trace) - maxContinuationLines
		trace = append(append([]string(nil), trace[:maxContinuationLines]...), fmt.Sprintf("… %d lignes de trace omises …", dropped))
	}
	source := e.SourceLabel
	if e.Module != "" {
		source += "-" + e.Module
	}
	message := e.Message
	if message == "" {
		message = e.Raw
	}
	out := ExcerptEntry{
		Lineno: e.Lineno, Timestamp: e.TimeOnly(), Level: e.Level,
		Source: r.Redact(source), SourceID: e.Source, Subsystem: r.Redact(e.Subsystem),
		Message: r.Redact(message), Noise: e.Noise,
	}
	for _, l := range trace {
		out.Continuations = append(out.Continuations, r.Redact(l))
	}
	return out
}

// fit keeps as many records as the ceiling allows, alternately from the head
// (the cause) and from the tail (the symptom). `at` builds the record of a
// position on demand: only the two ends are ever read, so a view of a million
// lines costs the few records that fit, not a million redactions.
func fit(count int, at func(int) ExcerptEntry, maxChars int) ([]ExcerptEntry, int) {
	if count == 0 {
		return nil, 0
	}
	if maxChars <= 0 {
		return nil, count
	}
	budget := maxChars
	var head, tail []ExcerptEntry
	low, high := 0, count-1
	takeHead := true
	for low <= high {
		index := high
		if takeHead {
			index = low
		}
		entry := at(index)
		cost := runeLen(entry.Render()) + 1
		if cost > budget && (len(head) > 0 || len(tail) > 0) {
			break
		}
		budget -= cost
		if takeHead {
			head = append(head, entry)
			low++
		} else {
			tail = append(tail, entry)
			high--
		}
		takeHead = !takeHead
	}
	kept := head
	for i := len(tail) - 1; i >= 0; i-- {
		kept = append(kept, tail[i])
	}
	return kept, count - len(kept)
}

// bound refits until the whole rendered text sits inside maxChars, giving
// records back one at a time from the gap: a record is indivisible.
func bound(current Excerpt, count int, at func(int) ExcerptEntry, maxChars, already int) Excerpt {
	kept, dropped := fit(count, at, maxChars)
	current.Entries, current.Omitted = kept, already+dropped
	for len(current.Entries) > 0 && runeLen(current.Text()) > maxChars {
		current.Entries = withoutOne(current.Entries)
		current.Omitted++
	}
	return current
}

func withoutOne(entries []ExcerptEntry) []ExcerptEntry {
	cut := max(splitPoint(len(entries))-1, 0)
	out := append([]ExcerptEntry(nil), entries[:cut]...)
	return append(out, entries[cut+1:]...)
}

// BuildExcerpt is the bounded, redacted excerpt of the view: `visible` the
// rows shown (nil: the filters evaluated again), `f` the filters behind them.
func BuildExcerpt(r *Redactor, store *logcore.Store, f *logcore.FilterSet, visible []int, maxChars int) (Excerpt, error) {
	indices := visible
	if indices == nil {
		var err error
		if indices, err = logcore.Evaluate(store, f); err != nil {
			return Excerpt{}, err
		}
	}
	noiseOff := false
	for _, s := range f.Noise {
		noiseOff = noiseOff || s == logcore.StateOff
	}
	var allowed []int
	for _, i := range indices {
		if i >= 0 && i < store.Len() && !isExcluded(store, f, i, noiseOff) {
			allowed = append(allowed, i)
		}
	}
	x := Excerpt{
		TotalIndexed: store.Len(), Selected: len(allowed),
		Excluded: keysInState(f, logcore.StateOff), ContextOnly: keysInState(f, logcore.StateContext),
	}
	for _, t := range f.TextFilters {
		if !t.Disabled && t.Pattern != "" {
			// Typed by the user, so it may carry a name or an address: redacted like
			// the records, since the header travels to the Worker as it stands. The
			// Python does not (its report is redacted whole, its Worker excerpt is not).
			x.Searches = append(x.Searches, r.Redact(t.Describe()))
		}
	}
	at := func(i int) ExcerptEntry { return toExcerptEntry(r, store.Entry(allowed[i])) }
	return bound(x, len(allowed), at, maxChars, 0), nil
}
