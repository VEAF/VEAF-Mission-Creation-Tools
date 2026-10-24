package logcore

import (
	"encoding/json"
	"errors"
	"reflect"
	"slices"
	"strings"
	"testing"
)

// referenceJournal is test/python/veaf_logs_journal.py: a known ED error, two
// VEAF lines (a warning hidden under a DCS INFO), a CTLD line, a script error
// with its stack trace, a chatty ED warning. Six entries.
var referenceJournal = strings.Join([]string{
	"2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.",
	"2026-08-31 11:50:41.000 INFO    SCRIPTING (Main): VEAF|I|5390: Loading version 6.16.5",
	"2026-08-31 11:50:42.000 INFO    SCRIPTING (Main): VEAF|W|log|123: zone introuvable",
	"2026-08-31 11:50:43.000 INFO    SCRIPTING (Main): [CTLD][INFO] scene registered",
	"2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error: CSAR.lua:2213",
	"stack traceback:",
	"\t[C]: in function 'getUnitRecordById'",
	"2026-08-31 11:55:10.095 WARNING FLIGHT (Main): No taxiroad found on Batumi from 1 to 2",
}, "\n") + "\n"

func referenceStore(t *testing.T) *Store {
	t.Helper()
	store := NewStore(loadRules(t), &BytesBuffer{Data: []byte(referenceJournal)})
	store.IndexNew(0)
	if store.Len() != 6 {
		t.Fatalf("reference journal: %d entries, want 6", store.Len())
	}
	return store
}

func span(n int) *int { return &n }

func visible(t *testing.T, store *Store, f FilterSet) []int {
	t.Helper()
	got, err := Evaluate(store, &f)
	if err != nil {
		t.Fatal(err)
	}
	if got == nil {
		got = []int{}
	}
	return got
}

func all(n int) []int {
	out := make([]int, n)
	for i := range out {
		out[i] = i
	}
	return out
}

func mustCompile(t *testing.T, pattern string, mode Mode, caseSensitive bool) func(string) bool {
	t.Helper()
	re, err := CompilePattern(pattern, mode, caseSensitive)
	if err != nil {
		t.Fatal(err)
	}
	return func(s string) bool { return re.MatchString(s) }
}

func TestGlobToRegex(t *testing.T) {
	for in, want := range map[string]string{"VEAF*error": "VEAF.*error", "v?": "v."} {
		if got := GlobToRegex(in); got != want {
			t.Errorf("GlobToRegex(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestGlobKeepsEverythingElseLiteral(t *testing.T) {
	dot := mustCompile(t, "CSAR.lua", ModeGlob, false)
	if !dot("CSAR.lua") || dot("CSARxlua") {
		t.Error("the dot must stay literal in a glob")
	}
	if !mustCompile(t, "[CTLD]", ModeGlob, false)("[CTLD][INFO] x") {
		t.Error("brackets must be escaped")
	}
	bar := mustCompile(t, "VEAF|W|", ModeGlob, false)
	if !bar("VEAF|W|log|123: x") || bar("VEAF|I|5390: x") {
		t.Error("the vertical bar must stay literal")
	}
}

func TestModes(t *testing.T) {
	plain := mustCompile(t, "a.b", ModePlain, false)
	if !plain("xa.by") || plain("axb") {
		t.Error("plain text must be literal")
	}
	regex := mustCompile(t, `VEAF\|[WE]\|`, ModeRegex, false)
	if !regex("VEAF|W|log|1: x") || regex("VEAF|I|1: x") {
		t.Error("full regex")
	}
	if !mustCompile(t, "veaf", ModePlain, false)("VEAF|I|") {
		t.Error("case is ignored by default")
	}
	if mustCompile(t, "veaf", ModePlain, true)("VEAF|I|") {
		t.Error("case-sensitive")
	}
}

func TestInvalidRegexIsAPatternError(t *testing.T) {
	_, err := CompilePattern("[non fermee", ModeRegex, false)
	var pe *PatternError
	if !errors.As(err, &pe) {
		t.Fatalf("want a PatternError, got %v", err)
	}
}

func TestEmptyPatternCompilesToNothing(t *testing.T) {
	re, err := CompilePattern("", ModeRegex, false)
	if re != nil || err != nil {
		t.Errorf("empty pattern: %v, %v", re, err)
	}
}

func TestUnknownModeIsRejected(t *testing.T) {
	if _, err := ParseMode("inconnu"); err == nil {
		t.Error("an unknown mode must be rejected")
	}
}

func TestTextSearch(t *testing.T) {
	store := referenceStore(t)
	cases := []struct {
		name string
		f    FilterSet
		want []int
	}{
		{"no criterion", NewFilterSet(), all(6)},
		{"plain", withText(TextFilter{Pattern: "zone introuvable"}), []int{2}},
		{"inside an attached trace", withText(TextFilter{Pattern: "getUnitRecordById"}), []int{4}},
		{"regex", withText(TextFilter{Pattern: `VEAF\|[WE]\|`, Mode: ModeRegex}), []int{2}},
		{"glob", withText(TextFilter{Pattern: "No taxiroad*Batumi*", Mode: ModeGlob}), []int{5}},
		{"inverted", withText(TextFilter{Pattern: "VEAF", Invert: true}), []int{0, 3, 4, 5}},
		{"cumulative AND", withText(TextFilter{Pattern: "VEAF"}, TextFilter{Pattern: "zone"}), []int{2}},
		{"disabled is ignored", withText(TextFilter{Pattern: "zone", Disabled: true}), all(6)},
	}
	for _, c := range cases {
		if got := visible(t, store, c.f); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
}

func TestHighlightExcludesInvertedCriteria(t *testing.T) {
	f := withText(TextFilter{Pattern: "VEAF"}, TextFilter{Pattern: "x", Invert: true})
	if n := len(HighlightPatterns(&f)); n != 1 {
		t.Errorf("%d highlight patterns, want 1", n)
	}
}

func TestCategoryStates(t *testing.T) {
	store := referenceStore(t)
	cases := []struct {
		name string
		f    FilterSet
		want []int
	}{
		{"level hidden", FilterSet{Levels: states("INFO", StateOff)}, []int{0, 2, 4, 5}},
		{"source hidden", FilterSet{Sources: states("veaf", StateOff)}, []int{0, 3, 4, 5}},
		{"noise hidden", FilterSet{Noise: map[string]State{"damage_model": StateOff, "taxiroad": StateOff}}, []int{1, 2, 3, 4}},
		// Entries 1 and 2 are VEAF, so OFF whatever their level; entry 3 (INFO, CTLD) is context within 3 of entry 0.
		{"OFF beats CONTEXT", FilterSet{Levels: states("INFO", StateContext), Sources: states("veaf", StateOff)}, []int{0, 3, 4, 5}},
		{"unknown category shown", FilterSet{Levels: states("NOUVEAU", StateOff)}, all(6)},
	}
	for _, c := range cases {
		c.f.ContextLines = DefaultContextLines
		if got := visible(t, store, c.f); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
}

func TestCategoryContext(t *testing.T) {
	store := referenceStore(t)
	errorsOnly := func(lines int) FilterSet {
		return FilterSet{Levels: map[string]State{"INFO": StateContext, "WARNING": StateOff}, ContextLines: lines}
	}
	textual := errorsOnly(1)
	textual.TextFilters = []TextFilter{{Pattern: "Mission script error"}}
	cases := []struct {
		name string
		f    FilterSet
		want []int
	}{
		{"around the errors", errorsOnly(1), []int{0, 1, 3, 4}},
		{"zero span", errorsOnly(0), []int{0, 4}},
		{"wide span", errorsOnly(10), []int{0, 1, 3, 4}},
		{"context lines need not match the text", textual, []int{3, 4}},
		{"no category in context", FilterSet{Levels: states("INFO", StateOff), ContextLines: 5}, []int{0, 2, 4, 5}},
		{"no anchor, no context", FilterSet{Levels: map[string]State{"ERROR": StateOff, "WARNING": StateOff, "INFO": StateContext}, ContextLines: 50}, []int{}},
	}
	for _, c := range cases {
		if got := visible(t, store, c.f); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
	if (&FilterSet{}).UsesContext() || !(&FilterSet{Levels: states("INFO", StateContext)}).UsesContext() || (&FilterSet{Levels: states("INFO", StateOff)}).UsesContext() {
		t.Error("UsesContext")
	}
}

func TestSearchContext(t *testing.T) {
	store := referenceStore(t)
	zone := func(own *int, common int) FilterSet {
		f := withText(TextFilter{Pattern: "zone introuvable", ContextLines: own})
		f.SearchContextLines = common
		return f
	}
	hiddenInfo := zone(nil, 1)
	hiddenInfo.Levels = states("INFO", StateOff)
	hiddenCTLD := zone(nil, 1)
	hiddenCTLD.Sources = states("ctld", StateOff)
	widest := withText(TextFilter{Pattern: "VEAF"}, TextFilter{Pattern: "zone", ContextLines: span(2)})
	inverted := withText(TextFilter{Pattern: "VEAF", Invert: true, ContextLines: span(3)})
	disabled := withText(TextFilter{Pattern: "zone introuvable", Disabled: true})
	disabled.SearchContextLines = 2
	noText := FilterSet{Levels: states("INFO", StateOff), ContextLines: DefaultContextLines, SearchContextLines: 5}
	composed := FilterSet{
		Levels:       map[string]State{"INFO": StateContext, "WARNING": StateOff},
		TextFilters:  []TextFilter{{Pattern: "Mission script error"}},
		ContextLines: 1,
	}
	corrupt := withText(TextFilter{Pattern: "Corrupt damage model"})
	corrupt.SearchContextLines = 50
	cases := []struct {
		name string
		f    FilterSet
		want []int
	}{
		{"off by default", zone(nil, 0), []int{2}},
		{"common span", zone(nil, 1), []int{1, 2, 3}},
		{"wider span", zone(nil, 2), []int{0, 1, 2, 3, 4}},
		{"journal bounds", corrupt, all(6)},
		{"hidden categories stay hidden", hiddenInfo, []int{2}},
		{"only one neighbour allowed", hiddenCTLD, []int{1, 2}},
		{"per-criterion span", zone(span(2), 0), []int{0, 1, 2, 3, 4}},
		{"explicit zero beats the common span", zone(span(0), 2), []int{2}},
		{"the widest wins", widest, []int{0, 1, 2, 3, 4}},
		{"an inverted criterion brings no context", inverted, []int{0, 3, 4, 5}},
		{"disabled criterion ignored", disabled, all(6)},
		{"no text criterion", noText, []int{0, 2, 4, 5}},
		{"composes with category context", composed, []int{3, 4}},
	}
	for _, c := range cases {
		if got := visible(t, store, c.f); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
}

func TestSearchSpan(t *testing.T) {
	f := NewFilterSet()
	if f.SearchSpan() != 0 {
		t.Error("empty")
	}
	f.TextFilters = []TextFilter{{Pattern: "a"}}
	f.SearchContextLines = 3
	if f.SearchSpan() != 3 {
		t.Error("common span")
	}
	f.TextFilters[0].ContextLines = span(7)
	if f.SearchSpan() != 7 {
		t.Error("own span")
	}
}

func TestDescribe(t *testing.T) {
	for _, c := range []struct {
		f    TextFilter
		want string
	}{
		{TextFilter{Pattern: "a"}, "Texte : a"},
		{TextFilter{Pattern: "a", ContextLines: span(3)}, "Texte : a  ±3"},
		{TextFilter{Pattern: "foo", Mode: ModeRegex, Invert: true, ContextLines: span(5)}, "sans Regex : foo  ±5"},
		{TextFilter{Pattern: "x*", Mode: ModeGlob}, "Jokers : x*"},
	} {
		if got := c.f.Describe(); got != c.want {
			t.Errorf("Describe() = %q, want %q", got, c.want)
		}
	}
}

func TestSpans(t *testing.T) {
	f := FilterSet{ContextLines: 4}
	if f.SpanFor("levels", "INFO") != 4 {
		t.Error("default")
	}
	f.SetSpan("levels", "INFO", span(10))
	if f.SpanFor("levels", "INFO") != 10 || f.SpanFor("levels", "DEBUG") != 4 {
		t.Error("override")
	}
	if f.SpanFor("sources", "INFO") != 4 {
		t.Error("families are independent")
	}
	f.SetSpan("levels", "INFO", nil)
	if f.SpanFor("levels", "INFO") != 4 {
		t.Error("back to default")
	}
	f.SetSpan("levels", "INFO", span(4))
	if len(f.ContextSpans) != 0 {
		t.Error("an override equal to the default is not stored")
	}
}

func TestSpanApplied(t *testing.T) {
	store := referenceStore(t)
	f := FilterSet{Levels: map[string]State{"INFO": StateContext, "WARNING": StateOff}}
	if got := visible(t, store, f); !reflect.DeepEqual(got, []int{0, 4}) {
		t.Errorf("zero span: %v", got)
	}
	f.SetSpan("levels", "INFO", span(1))
	if got := visible(t, store, f); !reflect.DeepEqual(got, []int{0, 1, 3, 4}) {
		t.Errorf("INFO span 1: %v", got)
	}
	widest := FilterSet{Levels: map[string]State{"INFO": StateContext, "WARNING": StateOff}, Sources: states("veaf", StateContext)}
	widest.SetSpan("sources", "veaf", span(1))
	if got := visible(t, store, widest); !slices.Contains(got, 1) {
		t.Errorf("entry 1 (INFO span 0, VEAF span 1) must show: %v", got)
	}
}

func TestSetState(t *testing.T) {
	f := NewFilterSet()
	f.SetState("levels", "INFO", StateOff)
	if !reflect.DeepEqual(f.Levels, states("INFO", StateOff)) {
		t.Error("set")
	}
	f.SetState("levels", "INFO", StateOn)
	if len(f.Levels) != 0 {
		t.Error("back to ON removes the entry")
	}
}

func TestEmptyJournal(t *testing.T) {
	store := NewStore(loadRules(t), &BytesBuffer{})
	store.IndexNew(0)
	if got := visible(t, store, FilterSet{Levels: states("INFO", StateOff)}); len(got) != 0 {
		t.Errorf("%v", got)
	}
}

func TestCopyIsIndependent(t *testing.T) {
	f := FilterSet{Levels: states("INFO", StateOff), TextFilters: []TextFilter{{Pattern: "a"}}}
	f.SetSpan("levels", "INFO", span(9))
	c := f.Copy()
	c.Levels["INFO"] = StateContext
	c.TextFilters = append(c.TextFilters, TextFilter{Pattern: "b"})
	c.TextFilters[0].Pattern = "z"
	c.SetSpan("levels", "INFO", span(1))
	if f.Levels["INFO"] != StateOff || len(f.TextFilters) != 1 || f.TextFilters[0].Pattern != "a" || f.SpanFor("levels", "INFO") != 9 {
		t.Errorf("the copy shares state with the original: %+v", f)
	}
}

// The JSON is the one `FilterSet.to_dict` writes: profiles.json and
// session.json must stay readable by both viewers.
func TestJSONRoundTrip(t *testing.T) {
	f := FilterSet{
		Levels:             states("INFO", StateContext),
		Sources:            states("veaf", StateOff),
		Noise:              states("taxiroad", StateOff),
		TextFilters:        []TextFilter{{Pattern: "x", Mode: ModeRegex, Invert: true, ContextLines: span(4)}},
		ContextLines:       7,
		SearchContextLines: 2,
	}
	f.SetSpan("levels", "INFO", span(8))
	raw, err := json.Marshal(f)
	if err != nil {
		t.Fatal(err)
	}
	var back FilterSet
	if err := json.Unmarshal(raw, &back); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(f, back) {
		t.Errorf("round trip\n  in: %+v\n out: %+v", f, back)
	}
	var keys map[string]json.RawMessage
	_ = json.Unmarshal(raw, &keys)
	for _, k := range []string{"levels", "sources", "noise", "text_filters", "context_lines", "context_spans", "search_context_lines"} {
		if _, ok := keys[k]; !ok {
			t.Errorf("key %q missing from %s", k, raw)
		}
	}
}

func TestJSONToleratesWhatPythonTolerates(t *testing.T) {
	var f FilterSet
	err := json.Unmarshal([]byte(`{
		"levels": {"INFO": "on", "DEBUG": "off", "WARNING": "n_importe_quoi"},
		"text_filters": [{"pattern": "a", "mode": "?"}, {"mode": "plain"}, {"pattern": "b", "context_lines": "trois"}, {"pattern": "c", "context_lines": true}],
		"context_spans": {"levels:INFO": "beaucoup", "levels:X": true, "levels:Y": 2.9, "levels:Z": -4},
		"search_context_lines": "beaucoup"
	}`), &f)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(f.Levels, states("DEBUG", StateOff)) {
		t.Errorf("levels: %v", f.Levels)
	}
	if len(f.TextFilters) != 2 || f.TextFilters[0].Pattern != "b" || f.TextFilters[0].ContextLines != nil || f.TextFilters[1].ContextLines != nil {
		t.Errorf("text filters: %+v", f.TextFilters)
	}
	if !reflect.DeepEqual(f.ContextSpans, map[string]int{"levels:Y": 2, "levels:Z": 0}) {
		t.Errorf("context spans: %v", f.ContextSpans)
	}
	if f.SearchContextLines != 0 || f.ContextLines != DefaultContextLines {
		t.Errorf("spans: search %d, context %d", f.SearchContextLines, f.ContextLines)
	}
}

// TestKnownDivergencesFromPython pins where Go's RE2 and Python's `re` over
// bytes cannot agree, measured on the Python side on 2026-10-24 (the PRD lists
// them). Each line states what Python does; the assertion is what Go does.
func TestKnownDivergencesFromPython(t *testing.T) {
	store := NewStore(loadRules(t), &BytesBuffer{Data: []byte("É\naa\nVEAF|W|\nx\n\xa9\n")})
	store.IndexNew(0)
	match := func(pattern string) ([]int, error) {
		f := withText(TextFilter{Pattern: pattern, Mode: ModeRegex})
		return Evaluate(store, &f)
	}
	// Python folds ASCII only on bytes: `é` does not find `É`. Go's (?i) folds Unicode: it does.
	if got, _ := match("é"); !reflect.DeepEqual(got, []int{0}) {
		t.Errorf("é: %v, Go folds Unicode case", got)
	}
	// Python accepts these; RE2 has no lookaround, no backreference, no \Z.
	for _, p := range []string{`VEAF(?=\|W)`, `(a)\1`, `x\Z`} {
		var pe *PatternError
		if _, err := match(p); !errors.As(err, &pe) {
			t.Errorf("%s: want a PatternError, got %v", p, err)
		}
	}
	// Python encodes the class to bytes, so `[é]` matches the lone byte 0xA9 (entry 4); Go matches
	// the character only, here `É` through the same Unicode folding.
	if got, _ := match("[é]"); !reflect.DeepEqual(got, []int{0}) {
		t.Errorf("[é]: %v, Go matches characters, not bytes", got)
	}
}

func withText(filters ...TextFilter) FilterSet {
	f := NewFilterSet()
	f.TextFilters = filters
	return f
}

func states(key string, s State) map[string]State { return map[string]State{key: s} }
