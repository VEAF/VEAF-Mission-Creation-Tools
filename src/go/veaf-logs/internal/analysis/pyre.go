// Package analysis is *Explain* and the `/bug` report of the Python viewer
// (`veaf_logs.analysis`, `excerpt`, `catalogue`, `proposals`, `report`,
// `worker_client`, and `veaf_libs.redaction`, `diagnostics`): the same texts,
// to the character, proven against references the Python writes.
package analysis

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Python's `re` on str is Unicode where Go's regexp is ASCII, it counts code
// points where Go counts bytes, and it has lookbehind and lookahead where RE2
// has none. This file holds what the port needs to say the same thing.

// Class fragments of Python's `\w`, `\d` and `\s` on str, for use inside a
// Go character class.
const (
	pyW = `\p{L}\p{N}_`
	pyD = `\p{Nd}`
	pyS = `\t\n\v\f\r \x{1c}-\x{1f}\x{85}\x{a0}\p{Zs}\x{2028}\x{2029}`
)

// isWord is Python's `\w` on one character: alphanumeric or underscore.
func isWord(r rune) bool { return r == '_' || unicode.IsLetter(r) || unicode.IsNumber(r) }

// isSpace is Python's `str.isspace`: Go's White_Space plus the four
// information separators \x1c–\x1f, which Python counts as whitespace.
func isSpace(r rune) bool { return unicode.IsSpace(r) || (r >= 0x1c && r <= 0x1f) }

// runeLen is Python's len() of a str.
func runeLen(s string) int { return utf8.RuneCountInString(s) }

// runePrefix is s[:n] in Python, n counted in code points.
func runePrefix(s string, n int) string {
	if n <= 0 {
		return ""
	}
	i := 0
	for j := range s {
		if i == n {
			return s[:j]
		}
		i++
	}
	return s
}

// padRight is Python's f"{s:<n}".
func padRight(s string, n int) string {
	if k := runeLen(s); k < n {
		return s + strings.Repeat(" ", n-k)
	}
	return s
}

// pyStrip is Python's str.strip() with no argument.
func pyStrip(s string) string { return strings.TrimFunc(s, isSpace) }

// pyRStrip is Python's str.rstrip() with no argument.
func pyRStrip(s string) string { return strings.TrimRightFunc(s, isSpace) }

// pyFields is Python's str.split() with no argument.
func pyFields(s string) []string { return strings.FieldsFunc(s, isSpace) }

// pySplitLines is Python's str.splitlines(): every line boundary Python knows,
// a trailing one adding no empty line.
func pySplitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); {
		r, size := utf8.DecodeRuneInString(s[i:])
		switch r {
		case '\r':
			out = append(out, s[start:i])
			if i+1 < len(s) && s[i+1] == '\n' {
				size = 2
			}
			start = i + size
		case '\n', '\v', '\f', 0x1c, 0x1d, 0x1e, 0x85, 0x2028, 0x2029:
			out = append(out, s[start:i])
			start = i + size
		}
		i += size
	}
	if start < len(s) {
		out = append(out, s[start:])
	}
	return out
}

// decodeRune is the first character of s and its size, 0 when s is empty.
func decodeRune(s string) (rune, int) { return utf8.DecodeRuneInString(s) }

// before is the character just before byte offset i, and whether there is one.
func before(s string, i int) (rune, bool) {
	if i <= 0 {
		return 0, false
	}
	r, _ := utf8.DecodeLastRuneInString(s[:i])
	return r, true
}

// guarded is a pattern with a lookbehind Go cannot write. `re` matches the
// replaced text in one of its groups, possibly followed by one consumed
// character standing for a negative lookahead (`(?:[^…]|$)`); `refuse` says,
// for the group that matched, whether the text before it forbids the match.
// A refused match is retried one character further, as Python's scanner does.
type guarded struct {
	re     *regexp.Regexp
	refuse func(s string, at, group int) bool
}

// replace is re.sub(pattern, f, s) with the lookbehind applied.
func (g guarded) replace(s string, f func(group int, m []string) string) string {
	var out strings.Builder
	last, pos := 0, 0
	for pos <= len(s) {
		loc := g.re.FindStringSubmatchIndex(s[pos:])
		if loc == nil {
			break
		}
		group := 0
		for k := 1; 2*k < len(loc); k++ {
			if loc[2*k] >= 0 {
				group = k
				break
			}
		}
		start, end := pos+loc[2*group], pos+loc[2*group+1]
		if g.refuse != nil && g.refuse(s, start, group) {
			_, size := utf8.DecodeRuneInString(s[pos+loc[0]:])
			if size == 0 {
				break
			}
			pos = pos + loc[0] + size
			continue
		}
		out.WriteString(s[last:start])
		m := make([]string, len(loc)/2)
		for k := range m {
			if loc[2*k] >= 0 {
				m[k] = s[pos+loc[2*k] : pos+loc[2*k+1]]
			}
		}
		m[0] = s[start:end]
		out.WriteString(f(group, m))
		last, pos = end, end
		if end == start { // an empty match: step over one character, as Python does
			if pos >= len(s) {
				break
			}
			_, size := utf8.DecodeRuneInString(s[pos:])
			out.WriteString(s[pos : pos+size])
			last, pos = pos+size, pos+size
		}
	}
	out.WriteString(s[last:])
	return out.String()
}

// prevIn refuses a match preceded by a character `in` accepts.
func prevIn(in func(rune) bool) func(string, int, int) bool {
	return func(s string, at, _ int) bool {
		r, ok := before(s, at)
		return ok && in(r)
	}
}
