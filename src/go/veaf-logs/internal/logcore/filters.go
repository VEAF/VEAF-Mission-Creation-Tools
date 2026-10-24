package logcore

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"regexp/syntax"
	"sort"
	"strconv"
	"strings"
)

// Filtering and search, a port of veaf_logs/filters.py.
//
// Three search modes: plain text (substring), glob (`*` any run, `?` one
// character, everything else literal, not anchored) and full regex.
//
// Each category of the side panel (level, source, noise family) has three
// states: ON (shown), OFF (hidden), CONTEXT (shown only near a kept entry,
// like grep's -C). A text criterion keeps a neighbourhood too: the search
// context widens the search, it never undoes a category filter.

// Mode is how a text criterion reads its pattern.
type Mode string

const (
	ModePlain Mode = "plain"
	ModeGlob  Mode = "glob"
	ModeRegex Mode = "regex"
)

// ParseMode reads a mode as `filters.Mode(value)` does: an unknown value is an error.
func ParseMode(value string) (Mode, error) {
	switch Mode(value) {
	case ModePlain, ModeGlob, ModeRegex:
		return Mode(value), nil
	}
	return "", fmt.Errorf("%q is not a valid Mode", value)
}

// Label is the name the interface shows.
func (m Mode) Label() string {
	switch m {
	case ModeGlob:
		return "Jokers"
	case ModeRegex:
		return "Regex"
	}
	return "Texte"
}

func (m Mode) normalised() Mode {
	if m == "" {
		return ModePlain
	}
	return m
}

// State is the tri-state of a category.
type State string

const (
	StateOn      State = "on"
	StateOff     State = "off"
	StateContext State = "context"
)

const (
	// DefaultContextLines is the common span of categories in CONTEXT.
	DefaultContextLines = 3
	// DefaultSearchContextLines is zero: a search returns what it returned before the setting existed.
	DefaultSearchContextLines = 0
)

// PatternError is an invalid pattern (a malformed regex), shown to the user as it stands.
type PatternError struct{ Msg string }

func (e *PatternError) Error() string { return e.Msg }

// GlobToRegex translates a glob into a regex: `*` and `?` are the wildcards,
// everything else, `.` included, is literal. Unlike a file-name glob it is not
// anchored: it looks for a substring of a journal line.
func GlobToRegex(pattern string) string {
	var b strings.Builder
	for _, r := range pattern {
		switch r {
		case '*':
			b.WriteString(".*")
		case '?':
			b.WriteString(".")
		default:
			b.WriteString(regexp.QuoteMeta(string(r)))
		}
	}
	return b.String()
}

// PatternSource is the regex a pattern stands for in a given mode.
func PatternSource(pattern string, mode Mode) string {
	switch mode.normalised() {
	case ModePlain:
		return regexp.QuoteMeta(pattern)
	case ModeGlob:
		return GlobToRegex(pattern)
	}
	return pattern
}

// CompilePattern compiles a pattern for matching one line (highlighting, validation).
// An empty pattern compiles to nil; an invalid one is a *PatternError.
func CompilePattern(pattern string, mode Mode, caseSensitive bool) (*regexp.Regexp, error) {
	if pattern == "" {
		return nil, nil
	}
	re, err := regexp.Compile(flagged(PatternSource(pattern, mode), caseSensitive))
	if err != nil {
		return nil, &PatternError{Msg: err.Error()}
	}
	return re, nil
}

func flagged(expr string, caseSensitive bool) string {
	if caseSensitive {
		return expr
	}
	return "(?i)" + expr
}

// pythonDollar rewrites a regex to run over a block of the journal the way
// Python runs a bytes pattern over the block: a `$` outside multi-line mode
// also matches before the block's final newline. The rewrite only lets the
// match consume that newline; where it starts, which is what decides the entry,
// does not move.
func pythonDollar(re *syntax.Regexp) *syntax.Regexp {
	if re.Op == syntax.OpEndText && re.Flags&syntax.WasDollar != 0 {
		newline := &syntax.Regexp{Op: syntax.OpLiteral, Rune: []rune{'\n'}, Flags: re.Flags &^ syntax.WasDollar}
		optional := &syntax.Regexp{Op: syntax.OpQuest, Sub: []*syntax.Regexp{newline}, Flags: re.Flags &^ syntax.WasDollar}
		end := &syntax.Regexp{Op: syntax.OpEndText, Flags: re.Flags &^ syntax.WasDollar}
		return &syntax.Regexp{Op: syntax.OpConcat, Sub: []*syntax.Regexp{optional, end}, Flags: re.Flags &^ syntax.WasDollar}
	}
	for i, sub := range re.Sub {
		re.Sub[i] = pythonDollar(sub)
	}
	return re
}

// TextFilter is one text criterion.
type TextFilter struct {
	Pattern       string
	Mode          Mode
	CaseSensitive bool
	Invert        bool
	// Disabled mirrors `enabled = False`; the zero value is an enabled criterion.
	Disabled bool
	// ContextLines is this criterion's own search span; nil follows the
	// common one. An explicit 0 is therefore not the same as nil.
	ContextLines *int
}

func (t TextFilter) active() bool { return !t.Disabled && t.Pattern != "" }

// Describe is the label of the criterion's chip.
func (t TextFilter) Describe() string {
	prefix := ""
	if t.Invert {
		prefix = "sans "
	}
	suffix := ""
	if t.ContextLines != nil {
		suffix = fmt.Sprintf("  ±%d", *t.ContextLines)
	}
	return prefix + t.Mode.normalised().Label() + " : " + t.Pattern + suffix
}

// FilterSet is the whole filtering state. The maps only hold categories whose
// state is not ON: an unknown category (a level appearing while following) is
// shown by default.
type FilterSet struct {
	Levels      map[string]State
	Sources     map[string]State
	Noise       map[string]State
	TextFilters []TextFilter

	// ContextLines is the default span of categories in CONTEXT, and
	// ContextSpans its overrides, keyed "<kind>:<key>" (e.g. "levels:INFO").
	ContextLines int
	ContextSpans map[string]int

	// SearchContextLines is the common span around search results, which each
	// TextFilter may override with its own ContextLines.
	SearchContextLines int
}

// NewFilterSet is `FilterSet()`: nothing filtered, default spans.
func NewFilterSet() FilterSet {
	return FilterSet{ContextLines: DefaultContextLines, SearchContextLines: DefaultSearchContextLines}
}

func (f *FilterSet) table(kind string) *map[string]State {
	switch kind {
	case "levels":
		return &f.Levels
	case "sources":
		return &f.Sources
	case "noise":
		return &f.Noise
	}
	panic("unknown category kind " + kind)
}

// SetState sets a category's state; back to ON removes the entry.
func (f *FilterSet) SetState(kind, key string, state State) {
	table := f.table(kind)
	if state == StateOn {
		delete(*table, key)
		return
	}
	if *table == nil {
		*table = map[string]State{}
	}
	(*table)[key] = state
}

// SpanKey is the key of a category's span override.
func SpanKey(kind, key string) string { return kind + ":" + key }

// SpanFor is a category's context span: its override, or the default.
func (f *FilterSet) SpanFor(kind, key string) int {
	if span, ok := f.ContextSpans[SpanKey(kind, key)]; ok {
		return span
	}
	return f.ContextLines
}

// SetSpan sets a category's own span; nil, or the default value, removes the override.
func (f *FilterSet) SetSpan(kind, key string, span *int) {
	composite := SpanKey(kind, key)
	if span == nil || *span == f.ContextLines {
		delete(f.ContextSpans, composite)
		return
	}
	if f.ContextSpans == nil {
		f.ContextSpans = map[string]int{}
	}
	f.ContextSpans[composite] = max(0, *span)
}

// SearchSpan is the span around search results: the widest among active,
// non-inverted criteria — an inverted one has no result to surround.
func (f *FilterSet) SearchSpan() int {
	span := 0
	for _, t := range f.TextFilters {
		if !t.active() || t.Invert {
			continue
		}
		own := f.SearchContextLines
		if t.ContextLines != nil {
			own = *t.ContextLines
		}
		span = max(span, own)
	}
	return span
}

// UsesContext tells whether any category is in CONTEXT.
func (f *FilterSet) UsesContext() bool {
	for _, table := range []map[string]State{f.Levels, f.Sources, f.Noise} {
		for _, s := range table {
			if s == StateContext {
				return true
			}
		}
	}
	return false
}

// IsEmpty tells that nothing filters: the scan can be skipped.
func (f *FilterSet) IsEmpty() bool {
	if len(f.Levels) > 0 || len(f.Sources) > 0 || len(f.Noise) > 0 {
		return false
	}
	for _, t := range f.TextFilters {
		if t.active() {
			return false
		}
	}
	return true
}

// Copy is a deep copy: editing it never touches the original (a loaded profile).
func (f FilterSet) Copy() FilterSet {
	out := f
	out.Levels = copyStates(f.Levels)
	out.Sources = copyStates(f.Sources)
	out.Noise = copyStates(f.Noise)
	if f.ContextSpans != nil {
		out.ContextSpans = make(map[string]int, len(f.ContextSpans))
		for k, v := range f.ContextSpans {
			out.ContextSpans[k] = v
		}
	}
	if f.TextFilters != nil {
		out.TextFilters = make([]TextFilter, len(f.TextFilters))
		for i, t := range f.TextFilters {
			if t.ContextLines != nil {
				own := *t.ContextLines
				t.ContextLines = &own
			}
			out.TextFilters[i] = t
		}
	}
	return out
}

func copyStates(m map[string]State) map[string]State {
	if m == nil {
		return nil
	}
	out := make(map[string]State, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

// -- persistence -------------------------------------------------------------
//
// The JSON is the one `FilterSet.to_dict` writes and `from_dict` reads, with
// its tolerances: profiles.json and session.json stay readable by both viewers.

type textFilterJSON struct {
	Pattern       string `json:"pattern"`
	Mode          Mode   `json:"mode"`
	CaseSensitive bool   `json:"case_sensitive"`
	Invert        bool   `json:"invert"`
	Enabled       bool   `json:"enabled"`
	ContextLines  *int   `json:"context_lines"`
}

type filterSetJSON struct {
	Levels             map[string]State `json:"levels"`
	Sources            map[string]State `json:"sources"`
	Noise              map[string]State `json:"noise"`
	TextFilters        []textFilterJSON `json:"text_filters"`
	ContextLines       int              `json:"context_lines"`
	ContextSpans       map[string]int   `json:"context_spans"`
	SearchContextLines int              `json:"search_context_lines"`
}

// MarshalJSON writes what `FilterSet.to_dict` writes.
func (f FilterSet) MarshalJSON() ([]byte, error) {
	out := filterSetJSON{
		Levels: nonNil(f.Levels), Sources: nonNil(f.Sources), Noise: nonNil(f.Noise),
		TextFilters:  []textFilterJSON{},
		ContextLines: f.ContextLines, ContextSpans: f.ContextSpans, SearchContextLines: f.SearchContextLines,
	}
	if out.ContextSpans == nil {
		out.ContextSpans = map[string]int{}
	}
	for _, t := range f.TextFilters {
		out.TextFilters = append(out.TextFilters, textFilterJSON{
			Pattern: t.Pattern, Mode: t.Mode.normalised(), CaseSensitive: t.CaseSensitive,
			Invert: t.Invert, Enabled: !t.Disabled, ContextLines: t.ContextLines,
		})
	}
	return json.Marshal(out)
}

func nonNil(m map[string]State) map[string]State {
	if m == nil {
		return map[string]State{}
	}
	return m
}

// UnmarshalJSON reads what `FilterSet.from_dict` reads: an invalid state, mode
// or criterion is skipped, a span that is not a number falls back, `true` is
// not a span. A `context_lines` Python's int() refuses is an error, as there.
func (f *FilterSet) UnmarshalJSON(data []byte) error {
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	out := NewFilterSet()
	out.Levels = readStates(raw["levels"])
	out.Sources = readStates(raw["sources"])
	out.Noise = readStates(raw["noise"])
	if items, ok := raw["text_filters"].([]any); ok {
		for _, item := range items {
			if t, ok := readTextFilter(item); ok {
				out.TextFilters = append(out.TextFilters, t)
			}
		}
	}
	if value, present := raw["context_lines"]; present {
		lines, err := pythonInt(value)
		if err != nil {
			return err
		}
		out.ContextLines = lines
	}
	if spans, ok := raw["context_spans"].(map[string]any); ok {
		out.ContextSpans = map[string]int{}
		for key, value := range spans {
			if n, ok := value.(float64); ok {
				out.ContextSpans[key] = max(0, int(n))
			}
		}
	}
	if span := readOptionalSpan(raw["search_context_lines"]); span != nil {
		out.SearchContextLines = *span
	}
	*f = out
	return nil
}

func readStates(value any) map[string]State {
	out := map[string]State{}
	table, _ := value.(map[string]any)
	for key, raw := range table {
		s, _ := raw.(string)
		switch State(s) {
		case StateOff, StateContext:
			out[key] = State(s)
		}
	}
	return out
}

func readTextFilter(value any) (TextFilter, bool) {
	raw, ok := value.(map[string]any)
	if !ok {
		return TextFilter{}, false
	}
	pattern, ok := raw["pattern"].(string)
	if !ok {
		return TextFilter{}, false
	}
	mode := ModePlain
	if v, present := raw["mode"]; present {
		s, _ := v.(string)
		m, err := ParseMode(s)
		if err != nil {
			return TextFilter{}, false
		}
		mode = m
	}
	enabled := true
	if v, present := raw["enabled"]; present {
		enabled = truthy(v)
	}
	return TextFilter{
		Pattern: pattern, Mode: mode,
		CaseSensitive: truthy(raw["case_sensitive"]), Invert: truthy(raw["invert"]),
		Disabled: !enabled, ContextLines: readOptionalSpan(raw["context_lines"]),
	}, true
}

// readOptionalSpan is `_read_optional_span`: nil unless the value is a number (a boolean is not).
func readOptionalSpan(value any) *int {
	n, ok := value.(float64)
	if !ok {
		return nil
	}
	span := max(0, int(n))
	return &span
}

// truthy is Python's bool() over a JSON value.
func truthy(value any) bool {
	switch v := value.(type) {
	case nil:
		return false
	case bool:
		return v
	case float64:
		return v != 0
	case string:
		return v != ""
	case []any:
		return len(v) > 0
	case map[string]any:
		return len(v) > 0
	}
	return true
}

// pythonInt is Python's int() over a JSON value.
func pythonInt(value any) (int, error) {
	switch v := value.(type) {
	case bool:
		if v {
			return 1, nil
		}
		return 0, nil
	case float64:
		return int(v), nil
	case string:
		n, err := strconv.Atoi(strings.TrimSpace(v))
		if err != nil {
			return 0, fmt.Errorf("invalid literal for int(): %q", v)
		}
		return n, nil
	}
	return 0, fmt.Errorf("int() argument must be a string or a number, not %T", value)
}

// -- evaluation ---------------------------------------------------------------

// Evaluate returns the indexes of the visible entries, in journal order.
//
// Categories first sort each entry into kept, hidden or context; text criteria
// then narrow the kept entries only — a context line need not contain the text,
// or it would bring nothing; neighbourhoods are added last. The search context
// can only bring back what the categories allowed before the text criteria
// narrowed, and its additions are not anchors themselves; the category context
// then runs over the widened set.
func Evaluate(store *Store, f *FilterSet) ([]int, error) {
	total := store.Len()
	if total == 0 {
		return nil, nil
	}
	if f.IsEmpty() {
		out := make([]int, total)
		for i := range out {
			out[i] = i
		}
		return out, nil
	}

	kept, spans := classify(store, f)
	searchSpan := f.SearchSpan()
	var allowed []bool
	if searchSpan > 0 {
		allowed = append([]bool(nil), kept...)
	}
	for _, t := range f.TextFilters {
		if !t.active() {
			continue
		}
		if err := applyText(store, kept, t); err != nil {
			return nil, err
		}
	}
	if searchSpan > 0 {
		addSearchContext(kept, allowed, searchSpan)
	}
	if spans != nil {
		addContext(kept, spans)
	}

	var out []int
	for i, k := range kept {
		if k {
			out = append(out, i)
		}
	}
	return out, nil
}

// worse is the order of states: OFF beats CONTEXT, which beats ON.
func worse(current, candidate State) State {
	if current == StateOff || candidate == StateOff {
		return StateOff
	}
	if current == StateContext || candidate == StateContext {
		return StateContext
	}
	return StateOn
}

// classify splits the entries into kept and context candidates. The second
// slice gives each context entry its span (nil when no entry is context); when
// several of an entry's categories are in context, the widest span wins.
func classify(store *Store, f *FilterSet) ([]bool, []int) {
	total := store.Len()
	kept := make([]bool, total)
	if len(f.Levels) == 0 && len(f.Sources) == 0 && len(f.Noise) == 0 {
		for i := range kept {
			kept[i] = true
		}
		return kept, nil
	}

	// Per-id lookups instead of names: the store keeps ids, a map lookup per entry would cost more than the rest.
	levelState, levelSpan := make([]State, len(Levels)), make([]int, len(Levels))
	for id, name := range Levels {
		levelState[id] = stateOf(f.Levels, name)
		levelSpan[id] = f.SpanFor("levels", name)
	}
	sourceState, sourceSpan := make([]State, len(store.m.sourceIDs)), make([]int, len(store.m.sourceIDs))
	for id, name := range store.m.sourceIDs {
		sourceState[id] = stateOf(f.Sources, name)
		sourceSpan[id] = f.SpanFor("sources", name)
	}
	var offNoise, contextNoise uint64
	noiseSpan := make([]int, len(store.m.noiseOrder))
	for bit, name := range store.m.noiseOrder {
		switch stateOf(f.Noise, name) {
		case StateOff:
			offNoise |= 1 << uint(bit)
		case StateContext:
			contextNoise |= 1 << uint(bit)
			noiseSpan[bit] = f.SpanFor("noise", name)
		}
	}

	var spans []int
	for i := 0; i < total; i++ {
		state, span := levelState[store.level[i]], 0
		if state == StateContext {
			span = levelSpan[store.level[i]]
		}
		if state != StateOff {
			found := sourceState[store.source[i]]
			state = worse(state, found)
			if found == StateContext {
				span = max(span, sourceSpan[store.source[i]])
			}
		}
		if state != StateOff {
			mask := store.noise[i]
			if mask&offNoise != 0 {
				state = StateOff
			} else if hit := mask & contextNoise; hit != 0 {
				state = worse(state, StateContext)
				for bit := range noiseSpan {
					if hit&(1<<uint(bit)) != 0 {
						span = max(span, noiseSpan[bit])
					}
				}
			}
		}
		switch {
		case state == StateOn:
			kept[i] = true
		case state == StateContext && span > 0:
			if spans == nil {
				spans = make([]int, total)
			}
			spans[i] = span
		}
	}
	return kept, spans
}

func stateOf(table map[string]State, key string) State {
	if s, ok := table[key]; ok {
		return s
	}
	return StateOn
}

// applyText narrows kept to the entries satisfying one criterion. The journal
// is scanned in the same blocks as Python's `iter_blocks` — a `^` anchors to
// the start of a block on both sides — and each match is brought back to its
// entry: entries cover the file without gaps, so a match inside a stack trace
// designates the error that carries it.
func applyText(store *Store, kept []bool, t TextFilter) error {
	m, err := newTextMatcher(t)
	if err != nil {
		return err
	}
	found := make([]bool, len(kept))
	store.iterBlocks(func(first int, base int64, data []byte) {
		entryAt := func(pos int) int {
			abs := base + int64(pos)
			return first + sort.Search(len(store.offset)-first, func(k int) bool { return store.offset[first+k] > abs }) - 1
		}
		m.scan(data, entryAt, func(index int) { found[index] = true })
	})
	for i, hit := range found {
		if hit == t.Invert {
			kept[i] = false
		}
	}
	return nil
}

// textMatcher finds the entries a criterion matches in one block, by the
// cheapest of three ways that give the same entries as the full regex.
//
//   - Plain text: the pattern is a literal, so a byte search does — over a copy
//     of the block lowered in ASCII when case is ignored, which is exactly what
//     Python's IGNORECASE does on bytes.
//   - A regex with no anchor that cannot match a newline: every match lies on
//     one line and contains one of the required literals, so only the lines
//     holding a literal are tried. Go's case-insensitive regexp costs several
//     times Python's over a whole journal; most lines hold no literal.
//   - Anything else: the regex over the whole block, as Python runs it.
type textMatcher struct {
	plain  []byte
	fold   bool
	lits   [][]byte
	line   *regexp.Regexp
	stream *pattern
}

func newTextMatcher(t TextFilter) (*textMatcher, error) {
	fold := !t.CaseSensitive
	if t.Mode.normalised() == ModePlain {
		lit := []byte(t.Pattern)
		if fold {
			lit = asciiLower(lit)
		}
		return &textMatcher{plain: lit, fold: fold}, nil
	}
	source := flagged(PatternSource(t.Pattern, t.Mode), t.CaseSensitive)
	tree, err := syntax.Parse(source, syntax.Perl)
	if err != nil {
		return nil, &PatternError{Msg: err.Error()}
	}
	if lineLocal(tree) {
		if lits, ok := requiredLiterals(tree, fold); ok {
			line, err := regexp.Compile(source)
			if err != nil {
				return nil, &PatternError{Msg: err.Error()}
			}
			return &textMatcher{fold: fold, lits: lits, line: line}, nil
		}
	}
	stream, err := newPattern(pythonDollar(tree).String())
	if err != nil {
		return nil, &PatternError{Msg: err.Error()}
	}
	return &textMatcher{stream: stream}, nil
}

// lineLocal tells that the regex has no anchor and cannot match a newline:
// trying it line by line then finds exactly the lines the block scan finds.
// A word boundary is fine — before a line, the block holds a newline, which
// is no more a word character than the start of the text.
func lineLocal(re *syntax.Regexp) bool {
	switch re.Op {
	case syntax.OpBeginLine, syntax.OpEndLine, syntax.OpBeginText, syntax.OpEndText, syntax.OpAnyChar:
		return false
	case syntax.OpLiteral:
		for _, r := range re.Rune {
			if r == '\n' {
				return false
			}
		}
	case syntax.OpCharClass:
		for i := 0; i+1 < len(re.Rune); i += 2 {
			if re.Rune[i] <= '\n' && '\n' <= re.Rune[i+1] {
				return false
			}
		}
	}
	for _, sub := range re.Sub {
		if !lineLocal(sub) {
			return false
		}
	}
	return true
}

func (m *textMatcher) scan(data []byte, entryAt func(int) int, hit func(int)) {
	switch {
	case m.plain != nil:
		haystack := data
		if m.fold {
			haystack = asciiLower(data)
		}
		for pos := 0; ; {
			i := bytes.Index(haystack[pos:], m.plain)
			if i < 0 {
				return
			}
			index := entryAt(pos + i)
			hit(index)
			// One hit per entry is enough: resume at the next line, the entry's continuation lines included.
			next := bytes.IndexByte(haystack[pos+i:], '\n')
			if next < 0 {
				return
			}
			pos += i + next + 1
		}
	case m.line != nil:
		haystack := data
		if m.fold {
			haystack = asciiLower(data)
		}
		for pos := 0; pos < len(data); {
			i := nextLiteral(haystack[pos:], m.lits)
			if i < 0 {
				return
			}
			start := pos + i
			lineStart := bytes.LastIndexByte(data[:start], '\n') + 1
			lineEnd := len(data)
			if n := bytes.IndexByte(data[start:], '\n'); n >= 0 {
				lineEnd = start + n
			}
			if m.line.Match(data[lineStart:lineEnd]) {
				hit(entryAt(lineStart))
			}
			pos = lineEnd + 1
		}
	default:
		if !m.stream.possible(data) {
			return
		}
		for _, loc := range m.stream.re.FindAllIndex(data, -1) {
			if index := entryAt(loc[0]); index >= 0 {
				hit(index)
			}
		}
	}
}

// nextLiteral is the first position of any of the literals, or -1.
func nextLiteral(b []byte, lits [][]byte) int {
	best := -1
	for _, l := range lits {
		limit := b
		if best >= 0 {
			limit = b[:min(len(b), best+len(l))]
		}
		if i := bytes.Index(limit, l); i >= 0 && (best < 0 || i < best) {
			best = i
		}
	}
	return best
}

// addSearchContext reopens the neighbourhood of the search results among the
// entries the categories allowed.
func addSearchContext(kept, allowed []bool, span int) {
	anchors := anchorsOf(kept)
	if len(anchors) == 0 {
		return
	}
	for i, permitted := range allowed {
		if permitted && !kept[i] && nearAnchor(anchors, i, span) {
			kept[i] = true
		}
	}
}

// addContext adds the context entries close enough to a kept entry.
func addContext(kept []bool, spans []int) {
	anchors := anchorsOf(kept)
	if len(anchors) == 0 {
		return
	}
	for i, span := range spans {
		if span > 0 && nearAnchor(anchors, i, span) {
			kept[i] = true
		}
	}
}

func anchorsOf(kept []bool) []int {
	var anchors []int
	for i, k := range kept {
		if k {
			anchors = append(anchors, i)
		}
	}
	return anchors
}

func nearAnchor(anchors []int, index, span int) bool {
	position := sort.SearchInts(anchors, index)
	if position < len(anchors) && anchors[position]-index <= span {
		return true
	}
	return position > 0 && index-anchors[position-1] <= span
}

// HighlightPatterns are the positive criteria only: those are highlighted in the message.
func HighlightPatterns(f *FilterSet) []*regexp.Regexp {
	var out []*regexp.Regexp
	for _, t := range f.TextFilters {
		if !t.active() || t.Invert {
			continue
		}
		if re, err := CompilePattern(t.Pattern, t.Mode, t.CaseSensitive); err == nil && re != nil {
			out = append(out, re)
		}
	}
	return out
}
