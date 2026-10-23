package logcore

import (
	"bytes"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

const (
	noFormat = 0xFF
	// Suites an entry may carry (the Python array is "H"): beyond it the line
	// opens an entry that inherits format, level and source.
	maxContinuations = 0xFFFF
	// Index chunk size: bounds the memory copied by each pass.
	indexChunk = 8 << 20
)

// Entry is one journal entry: a header line and its continuation lines.
type Entry struct {
	Lineno       int
	Raw          string
	Timestamp    string
	Level        string
	Subsystem    string
	Message      string
	Source       string
	SourceLabel  string
	Module       string
	Noise        []string
	Continuation []string
}

// Store is the compact index of a journal: parallel arrays, the text stays in the Buffer.
type Store struct {
	rules  *Rules
	buffer Buffer

	offset  []int64
	length  []uint32
	msgAt   []uint16
	level   []uint8
	source  []uint8
	module  []uint16
	noise   []uint64
	lineno  []uint32
	conts   []uint16
	format  []uint8
	Modules []string

	moduleIndex map[string]uint16
	cursor      int64
	linesSeen   uint32
	maxMessage  int

	m *matchers

	byLevel  map[string]int
	bySource map[string]int
	byNoise  map[string]int
}

// NewStore creates an empty index over a buffer.
func NewStore(rules *Rules, buffer Buffer) *Store {
	s := &Store{rules: rules, buffer: buffer, m: newMatchers(rules)}
	s.Clear()
	return s
}

// Len is the number of entries.
func (s *Store) Len() int { return len(s.offset) }

// Clear empties the index.
func (s *Store) Clear() {
	s.offset, s.length, s.msgAt, s.level, s.source = nil, nil, nil, nil, nil
	s.module, s.noise, s.lineno, s.conts, s.format = nil, nil, nil, nil, nil
	s.Modules = []string{""}
	s.moduleIndex = map[string]uint16{"": 0}
	s.cursor, s.linesSeen, s.maxMessage = 0, 0, 0
	s.byLevel, s.bySource, s.byNoise = map[string]int{}, map[string]int{}, map[string]int{}
}

// IndexNew indexes what was written since the last call (maxBytes <= 0: no
// bound) and returns the number of entries added. An incomplete last line is
// left for later.
func (s *Store) IndexNew(maxBytes int64) int {
	size := s.buffer.Refresh()
	if size <= s.cursor {
		return 0
	}
	if maxBytes > 0 && size > s.cursor+maxBytes {
		size = s.cursor + maxBytes
	}
	before := len(s.offset)
	for s.cursor < size {
		base := s.cursor
		n := size - base
		if n > indexChunk {
			n = indexChunk
		}
		data := s.buffer.Slice(base, n)
		cut := bytes.LastIndexByte(data, '\n')
		if cut < 0 {
			break
		}
		data = data[:cut+1]
		s.cursor += int64(len(data))
		pos := 0
		for {
			end := bytes.IndexByte(data[pos:], '\n')
			if end < 0 {
				break
			}
			s.addLine(base+int64(pos), data[pos:pos+end], uint32(end+1))
			pos += end + 1
		}
	}
	return len(s.offset) - before
}

func (s *Store) addLine(offset int64, line []byte, rawLength uint32) {
	s.linesSeen++
	stripped := bytes.TrimRight(line, "\r")
	found, match := s.m.header(stripped)
	last := len(s.offset) - 1

	// A line with no header after a recognised entry is its continuation.
	suite := match == nil && last >= 0 && s.format[last] != noFormat && !s.m.logOpened.Match(stripped)
	plein := suite && s.conts[last] >= maxContinuations
	if plein {
		found = s.format[last]
	} else if suite {
		s.length[last] += rawLength
		s.conts[last]++
		add := s.m.noiseMask(stripped, stripped, s.format[last]) &^ s.noise[last]
		if add != 0 {
			s.noise[last] |= add
			s.countNoise(add)
		}
		return
	}

	s.offset = append(s.offset, offset)
	s.length = append(s.length, rawLength)
	s.lineno = append(s.lineno, s.linesSeen)
	s.conts = append(s.conts, 0)
	s.format = append(s.format, found)

	if match == nil {
		opened := s.m.logOpened.Match(stripped)
		if opened {
			s.format[len(s.format)-1] = dcsFormatIndex
		}
		s.msgAt = append(s.msgAt, 0)
		if len(stripped) > s.maxMessage {
			s.maxMessage = len(stripped)
		}
		if plein {
			s.level = append(s.level, s.level[last])
			s.source = append(s.source, s.source[last])
			s.module = append(s.module, s.module[last])
		} else {
			lv := levelIndex["UNKNOWN"]
			if opened {
				lv = levelIndex["INFO"]
			}
			s.level = append(s.level, lv)
			s.source = append(s.source, s.m.nativeSource)
			s.module = append(s.module, 0)
		}
		mask := s.m.noiseMask(stripped, stripped, found)
		s.noise = append(s.noise, mask)
		s.tally(s.level[len(s.level)-1], s.source[len(s.source)-1], mask)
		return
	}

	fmtc := s.m.compiled[found]
	var message []byte
	if fmtc.message >= 0 && match[2*fmtc.message] >= 0 {
		message = stripped[match[2*fmtc.message]:match[2*fmtc.message+1]]
	}
	at := 0
	if fmtc.message >= 0 && match[2*fmtc.message] >= 0 {
		at = match[2*fmtc.message]
	}
	if at > 0xFFFF {
		at = 0xFFFF
	}
	s.msgAt = append(s.msgAt, uint16(at))
	if l := len(stripped) - at; l > s.maxMessage {
		s.maxMessage = l
	}
	var levelTok []byte
	if fmtc.level >= 0 && match[2*fmtc.level] >= 0 {
		levelTok = stripped[match[2*fmtc.level]:match[2*fmtc.level+1]]
	}
	lv := s.m.levelID(found, levelTok)
	var src uint8
	var mod []byte
	if Formats[found].Scripts {
		var refined int
		src, mod, refined = s.m.classify(message)
		if refined >= 0 {
			lv = uint8(refined)
		}
	} else {
		src = s.m.formatSource(Formats[found].ID)
	}
	s.source = append(s.source, src)
	s.module = append(s.module, s.moduleID(mod))
	s.level = append(s.level, lv)
	mask := s.m.noiseMask(stripped, message, found)
	s.noise = append(s.noise, mask)
	s.tally(lv, src, mask)
}

func (s *Store) tally(level, source uint8, mask uint64) {
	s.byLevel[Levels[level]]++
	s.bySource[s.m.sourceIDs[source]]++
	if mask != 0 {
		s.countNoise(mask)
	}
}

func (s *Store) countNoise(mask uint64) {
	for _, name := range s.m.noiseNames(mask) {
		s.byNoise[name]++
	}
}

func (s *Store) moduleID(module []byte) uint16 {
	if len(module) == 0 {
		return 0
	}
	name := string(module)
	if i, ok := s.moduleIndex[name]; ok {
		return i
	}
	i := uint16(len(s.Modules))
	s.Modules = append(s.Modules, name)
	s.moduleIndex[name] = i
	return i
}

// Entry rebuilds a full entry, decoding on demand.
func (s *Store) Entry(index int) Entry {
	blob := s.buffer.Slice(s.offset[index], int64(s.length[index]))
	lines := splitLines(toValidUTF8(blob))
	raw := ""
	if len(lines) > 0 {
		raw = lines[0]
	}
	at := int(s.msgAt[index])
	message := raw
	if at > 0 {
		// The Python slices the decoded string with a byte offset; the header is
		// ASCII, so the two agree whenever the header is what comes before.
		message = sliceRunes(raw, at)
	}
	e := Entry{
		Lineno: int(s.lineno[index]), Raw: raw, Level: Levels[s.level[index]],
		Message: message, Source: s.m.sourceIDs[s.source[index]], Module: s.Modules[s.module[index]],
	}
	if len(lines) > 1 {
		e.Continuation = lines[1:]
	}
	e.SourceLabel = s.m.sourceLabels[s.source[index]]
	e.Noise = s.m.noiseNames(s.noise[index])
	e.Timestamp, e.Subsystem = s.m.stampOf(s.format[index], raw)
	if e.Source == NativeSource {
		if e.Subsystem != "" {
			e.SourceLabel = e.Subsystem
		} else {
			e.SourceLabel = NativeLabel
		}
	}
	return e
}

// LevelOf returns the level name of an entry without building it.
func (s *Store) LevelOf(i int) string { return Levels[s.level[i]] }

// SourceOf returns the source id of an entry.
func (s *Store) SourceOf(i int) string { return s.m.sourceIDs[s.source[i]] }

// Offset returns where the entry starts in the file.
func (s *Store) Offset(i int) int64 { return s.offset[i] }

// MaxMessageLength is the longest message seen, in bytes.
func (s *Store) MaxMessageLength() int { return s.maxMessage }

// IndexedBytes is the number of bytes already indexed.
func (s *Store) IndexedBytes() int64 { return s.cursor }

func (s *Store) CountsByLevel() map[string]int  { return copyCounts(s.byLevel) }
func (s *Store) CountsBySource() map[string]int { return copyCounts(s.bySource) }
func (s *Store) CountsByNoise() map[string]int  { return copyCounts(s.byNoise) }

func copyCounts(m map[string]int) map[string]int {
	out := make(map[string]int, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

// -- matchers --------------------------------------------------------------

type noiseTest struct {
	bit       uint64
	re        *pattern
	onMessage bool
}

type matchers struct {
	compiled     []compiledFormat
	logOpened    *regexp.Regexp
	sourceIDs    []string
	sourceLabels []string
	nativeSource uint8
	byFormat     map[string]uint8

	sources []sourceTest
	// noise tests to try per format; the last slot is for noFormat.
	noiseByFormat [][]noiseTest
	noiseOrder    []string
	noiseCache    map[uint64][]string
}

type sourceTest struct {
	position int
	src      *Source
}

func newMatchers(r *Rules) *matchers {
	m := &matchers{logOpened: regexp.MustCompile(LogOpenedPattern), byFormat: map[string]uint8{}, noiseCache: map[uint64][]string{0: nil}}
	for _, f := range Formats {
		m.compiled = append(m.compiled, compileFormat(f))
	}
	for _, s := range r.Sources {
		m.sourceIDs = append(m.sourceIDs, s.ID)
		m.sourceLabels = append(m.sourceLabels, s.Label)
	}
	m.sourceIDs = append(m.sourceIDs, NativeSource)
	m.sourceLabels = append(m.sourceLabels, NativeLabel)
	m.nativeSource = uint8(len(m.sourceIDs) - 1)
	for i := range r.Sources {
		s := &r.Sources[i]
		for _, fid := range s.Formats {
			if _, ok := m.byFormat[fid]; !ok {
				m.byFormat[fid] = uint8(i)
			}
		}
		if s.pattern != nil {
			m.sources = append(m.sources, sourceTest{position: i, src: s})
		}
	}
	m.noiseByFormat = make([][]noiseTest, len(Formats)+1)
	for bit, f := range r.Noise {
		m.noiseOrder = append(m.noiseOrder, f.ID)
		t := noiseTest{bit: 1 << uint(bit), re: f.pattern, onMessage: f.OnMessage}
		for pos := 0; pos <= len(Formats); pos++ {
			if len(f.Formats) == 0 || (pos < len(Formats) && contains(f.Formats, Formats[pos].ID)) {
				m.noiseByFormat[pos] = append(m.noiseByFormat[pos], t)
			}
		}
	}
	return m
}

func (m *matchers) header(line []byte) (uint8, []int) {
	for i := range m.compiled {
		if loc := m.compiled[i].re.FindSubmatchIndex(line); loc != nil {
			return uint8(i), loc
		}
	}
	return noFormat, nil
}

func (m *matchers) formatSource(id string) uint8 {
	if p, ok := m.byFormat[id]; ok {
		return p
	}
	return m.nativeSource
}

// classify returns (source index, module name, refined level or -1).
func (m *matchers) classify(message []byte) (uint8, []byte, int) {
	for _, t := range m.sources {
		loc := t.src.pattern.FindSubmatchIndex(message)
		if loc == nil {
			continue
		}
		var module []byte
		if t.src.modulePattern != nil {
			if f := t.src.modulePattern.FindSubmatchIndex(message); f != nil && len(f) >= 4 && f[2] >= 0 {
				module = message[f[2]:f[3]]
			}
		}
		return uint8(t.position), module, refine(t.src, message, loc)
	}
	return m.nativeSource, nil, -1
}

func refine(src *Source, message []byte, loc []int) int {
	if src.levelGroup == "" {
		return -1
	}
	g := src.pattern.SubexpIndex(src.levelGroup)
	if g < 0 || loc[2*g] < 0 {
		return -1
	}
	tok := string(message[loc[2*g]:loc[2*g+1]])
	if tok == "" {
		return -1
	}
	name, ok := src.levelMap[tok]
	if !ok {
		name = strings.ToUpper(tok)
	}
	if i, ok := levelIndex[name]; ok {
		return int(i)
	}
	return -1
}

func (m *matchers) levelID(format uint8, level []byte) uint8 {
	f := Formats[format]
	if len(level) == 0 {
		if i, ok := levelIndex[f.DefaultLevel]; ok {
			return i
		}
		return levelIndex["UNKNOWN"]
	}
	name := string(level)
	if mapped, ok := f.LevelMap[name]; ok {
		name = mapped
	}
	if i, ok := levelIndex[name]; ok {
		return i
	}
	return levelIndex["UNKNOWN"]
}

func (m *matchers) noiseMask(line, message []byte, format uint8) uint64 {
	var mask uint64
	pos := int(format)
	if format == noFormat {
		pos = len(Formats)
	}
	for _, t := range m.noiseByFormat[pos] {
		target := line
		if t.onMessage {
			target = message
		}
		if t.re.Match(target) {
			mask |= t.bit
		}
	}
	return mask
}

func (m *matchers) noiseNames(mask uint64) []string {
	if c, ok := m.noiseCache[mask]; ok {
		return c
	}
	var names []string
	for bit, name := range m.noiseOrder {
		if mask&(1<<uint(bit)) != 0 {
			names = append(names, name)
		}
	}
	m.noiseCache[mask] = names
	return names
}

// stampOf returns the timestamp ("AAAA-MM-JJ HH:MM:SS.mmm") and the subsystem of a header line.
func (m *matchers) stampOf(format uint8, raw string) (string, string) {
	if format != noFormat {
		f := m.compiled[format]
		if loc := f.re.FindStringSubmatchIndex(raw); loc != nil {
			group := func(i int) string {
				if i < 0 || loc[2*i] < 0 {
					return ""
				}
				return raw[loc[2*i]:loc[2*i+1]]
			}
			t := strings.ReplaceAll(group(f.time), ",", ".")
			if f.date >= 0 && loc[2*f.date] >= 0 {
				return group(f.date) + " " + t, group(f.subsystem)
			}
			return t, group(f.subsystem)
		}
	}
	// A line that starts with a date keeps its time even when its header is unknown.
	runes := []rune(raw)
	if len(runes) >= 5 && allDigits(runes[:4]) && runes[4] == '-' {
		if len(runes) > 23 {
			runes = runes[:23]
		}
		return string(runes), ""
	}
	return "", ""
}

func allDigits(r []rune) bool {
	for _, c := range r {
		if !unicode.IsDigit(c) {
			return false
		}
	}
	return len(r) > 0
}

// -- text helpers ------------------------------------------------------------

// toValidUTF8 decodes like Python's `decode("utf-8", "replace")`, one U+FFFD per bad byte.
func toValidUTF8(b []byte) string {
	if utf8.Valid(b) {
		return string(b)
	}
	var sb strings.Builder
	for len(b) > 0 {
		r, n := utf8.DecodeRune(b)
		if r == utf8.RuneError && n == 1 {
			sb.WriteRune(utf8.RuneError)
		} else {
			sb.Write(b[:n])
		}
		b = b[n:]
	}
	return sb.String()
}

func sliceRunes(s string, from int) string {
	if from <= 0 {
		return s
	}
	i := 0
	for n := 0; n < from && i < len(s); n++ {
		_, w := utf8.DecodeRuneInString(s[i:])
		i += w
	}
	return s[i:]
}

// splitLines mirrors Python's str.splitlines() (which splits on more than \n).
func splitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); {
		r, w := utf8.DecodeRuneInString(s[i:])
		switch r {
		case '\n', '\v', '\f', 0x1c, 0x1d, 0x1e, 0x85, 0x2028, 0x2029:
			out = append(out, s[start:i])
			i += w
			start = i
		case '\r':
			out = append(out, s[start:i])
			i += w
			if i < len(s) && s[i] == '\n' {
				i++
			}
			start = i
		default:
			i += w
		}
	}
	if start < len(s) {
		out = append(out, s[start:])
	}
	return out
}
