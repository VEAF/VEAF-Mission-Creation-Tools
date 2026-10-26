package analysis

import (
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// Proposals (`veaf_logs.proposals`): a recurring message the catalogue does not
// know, shaped as a rules.json entry — never applied, and checked before it is offered.

const (
	minOccurrences  = 3
	maxProposals    = 5
	maxPatternChars = 200
	minLiteralChars = 12
	maxLabelChars   = 60

	rejectEmpty              = "motif vide"
	rejectTooLong            = "motif trop long"
	rejectNestedQuantifier   = "quantificateur imbriqué (risque d'explosion combinatoire)"
	rejectAdjacentQuantifier = "deux jokers illimités côte à côte (risque d'explosion combinatoire)"
	rejectUnanchored         = "motif non ancré : il commence par un joker et se retrouverait n'importe où"
	rejectTooGeneral         = "trop peu de texte littéral : le motif attraperait n'importe quoi"
	rejectInvalid            = "motif invalide"
	rejectNoSelfMatch        = "le motif ne retrouve pas la ligne dont il est issu"

	placeholderHelp = "Proposition automatique, non vérifiée : reformuler cette explication avant d'ajouter la règle."
)

// placeholders, in the Python's declaration order, and the fragment each becomes.
var placeholders = []struct{ name, fragment string }{
	{"<q>", `'[^']*'`},
	{"<b>", `\[[^\]]*\]`},
	{"<path>", `\S+`},
	{"<hex>", `[0-9A-Fa-f]+`},
	{"<n>", `[\d.]+`},
	{"<ip>", `\S+`},
	{"<user>", `\S+`},
	{"<email>", `\S+`},
	{"<redacted>", `\S+`},
}

var (
	placeholderFragment = func() map[string]string {
		m := map[string]string{}
		for _, p := range placeholders {
			m[p.name] = p.fragment
		}
		return m
	}()
	placeholderSplit = func() *regexp.Regexp {
		names := make([]string, len(placeholders))
		for i, p := range placeholders {
			names[i] = regexp.QuoteMeta(p.name)
		}
		return regexp.MustCompile(strings.Join(names, "|"))
	}()

	// The variable parts of a message, in the Python's order: quoted and
	// bracketed spans before the numbers inside them.
	quoted = guarded{
		re: regexp.MustCompile(`('[^']*')`),
		refuse: prevIn(func(r rune) bool {
			return r < 128 && (r >= 'A' && r <= 'Z' || r >= 'a' && r <= 'z' || r >= '0' && r <= '9')
		}),
	}
	doubleQuoted = regexp.MustCompile(`"[^"]*"`)
	bracketed    = regexp.MustCompile(`\[[^\]]*\]`)
	pathLike     = regexp.MustCompile(`(?:[A-Za-z]:)?[\\/][` + pyW + `.\\/+-]{3,}`)
	hexPrefixed  = guarded{
		re:     regexp.MustCompile(`(0[xX][0-9A-Fa-f]+)(?:[^` + pyW + `]|$)`),
		refuse: prevIn(isWord),
	}
	hexRun = guarded{
		re: regexp.MustCompile(`([0-9A-Fa-f]{8,})(?:[^` + pyW + `]|$)`),
		refuse: func(s string, at, _ int) bool {
			if r, ok := before(s, at); ok && isWord(r) {
				return true
			}
			// (?![0-9]+\b): a run of plain digits is a number, not an identifier.
			i := at
			for i < len(s) && s[i] >= '0' && s[i] <= '9' {
				i++
			}
			if i == at {
				return false
			}
			r, size := rune(0), 0
			if i < len(s) {
				r, size = decodeRune(s[i:])
			}
			return size == 0 || !isWord(r)
		},
	}
	number = guarded{
		re:     regexp.MustCompile(`([` + pyD + `]+(?:\.[` + pyD + `]+)*)(?:[^` + pyW + `]|$)`),
		refuse: prevIn(isWord),
	}

	nestedQuantifier    = regexp.MustCompile(`\([^()]*[*+][^()]*\)[` + pyS + `]*[*+{]`)
	unbounded           = `(?:\[(?:[^\]\\]|\\.)*\]|\\[dDsSwW]|\.)[*+]`
	adjacentQuantifiers = regexp.MustCompile(unbounded + unbounded)
	escapedChar         = regexp.MustCompile(`\\(.)`)
	wordRun             = regexp.MustCompile(`[A-Za-z]{3,}`)
)

// Normalise collapses the variable parts of a message, so two occurrences of it look alike.
func Normalise(message string) string {
	text := quoted.replace(message, func(int, []string) string { return "<q>" })
	text = doubleQuoted.ReplaceAllLiteralString(text, "<q>")
	text = bracketed.ReplaceAllLiteralString(text, "<b>")
	text = pathLike.ReplaceAllLiteralString(text, "<path>")
	text = hexPrefixed.replace(text, func(int, []string) string { return "<hex>" })
	text = hexRun.replace(text, func(int, []string) string { return "<hex>" })
	text = number.replace(text, func(int, []string) string { return "<n>" })
	return strings.Join(pyFields(text), " ")
}

// pyEscape is Python's re.escape: the regex specials and the ASCII whitespace.
func pyEscape(s string) string {
	var b strings.Builder
	for _, r := range s {
		if strings.ContainsRune("()[]{}?*+-|^$\\.&~# \t\n\r\v\f", r) {
			b.WriteByte('\\')
		}
		b.WriteRune(r)
	}
	return b.String()
}

// PatternFrom builds the regular expression matching every message of this
// normalised form: escaped but for the placeholders, a run of the same
// wildcard emitted once, capped at a fragment boundary.
func PatternFrom(normalised string) string {
	var pieces []string
	last := 0
	for _, loc := range placeholderSplit.FindAllStringIndex(normalised, -1) {
		pieces = append(pieces, normalised[last:loc[0]], normalised[loc[0]:loc[1]])
		last = loc[1]
	}
	pieces = append(pieces, normalised[last:])
	var out []string
	length := 0
	for _, piece := range pieces {
		if piece == "" {
			continue
		}
		fragment, isPlaceholder := placeholderFragment[piece]
		if !isPlaceholder {
			fragment = pyEscape(piece)
		}
		if len(out) > 0 && fragment == out[len(out)-1] && isPlaceholder {
			continue
		}
		if length+runeLen(fragment) > maxPatternChars {
			break
		}
		out = append(out, fragment)
		length += runeLen(fragment)
	}
	return strings.Join(out, "")
}

// literalChars counts the characters of real text a pattern demands, outside its wildcards.
func literalChars(pattern string) int {
	stripped := pattern
	seen := map[string]bool{}
	for _, p := range placeholders {
		if !seen[p.fragment] {
			seen[p.fragment] = true
			stripped = strings.ReplaceAll(stripped, p.fragment, " ")
		}
	}
	stripped = escapedChar.ReplaceAllString(stripped, "$1")
	return runeLen(strings.ReplaceAll(stripped, " ", ""))
}

// goPattern is a generated pattern as Go must compile it to judge it as
// Python's re does: \S and \d are Unicode there.
func goPattern(pattern string) string {
	var b strings.Builder
	for i := 0; i < len(pattern); {
		if pattern[i] != '\\' || i+1 >= len(pattern) {
			r, size := decodeRune(pattern[i:])
			b.WriteRune(r)
			i += size
			continue
		}
		r, size := decodeRune(pattern[i+1:])
		switch r {
		case 'S':
			b.WriteString(`[^` + pyS + `]`)
		case 'd':
			b.WriteString(`\p{Nd}`)
		default:
			b.WriteByte('\\')
			b.WriteRune(r)
		}
		i += 1 + size
	}
	return b.String()
}

// ValidatePattern says why a generated pattern must not be offered, or "".
func ValidatePattern(pattern, sample string) string {
	switch {
	case pattern == "":
		return rejectEmpty
	case runeLen(pattern) > maxPatternChars:
		return rejectTooLong
	case nestedQuantifier.MatchString(pattern):
		return rejectNestedQuantifier
	case adjacentQuantifiers.MatchString(pattern):
		return rejectAdjacentQuantifier
	}
	for _, p := range placeholders {
		if strings.HasPrefix(pattern, p.fragment) {
			return rejectUnanchored
		}
	}
	if literalChars(pattern) < minLiteralChars {
		return rejectTooGeneral
	}
	re, err := regexp.Compile(goPattern(pattern))
	if err != nil {
		return fmt.Sprintf("%s : %v", rejectInvalid, err)
	}
	if !re.MatchString(sample) {
		return rejectNoSelfMatch
	}
	return ""
}

// ProposedRule is a candidate rules.json noise entry.
type ProposedRule struct {
	ID, Label, Help, Match string
	DefaultHidden          bool
	Family                 string
	Count                  int
	Sample                 string
}

func identifier(normalised string, taken map[string]bool) string {
	words := wordRun.FindAllString(normalised, -1)
	if len(words) > 3 {
		words = words[:3]
	}
	for i, w := range words {
		words[i] = strings.ToLower(w)
	}
	base := strings.Join(words, "_")
	if base == "" {
		base = "motif"
	}
	candidate := base
	for suffix := 2; taken[candidate]; suffix++ {
		candidate = fmt.Sprintf("%s_%d", base, suffix)
	}
	return candidate
}

func label(normalised string) string {
	if runeLen(normalised) <= maxLabelChars {
		return normalised
	}
	return pyRStrip(runePrefix(normalised, maxLabelChars-1)) + "…"
}

// ProposeRules finds the recurring messages the catalogue does not cover, most frequent first.
func ProposeRules(rules *logcore.Rules, x Excerpt) []ProposedRule {
	groups := map[string][]ExcerptEntry{}
	var order []string
	for _, e := range Uncatalogued(rules, x) {
		message := pyStrip(e.Message)
		if message == "" {
			continue
		}
		key := Normalise(message)
		if _, ok := groups[key]; !ok {
			order = append(order, key)
		}
		groups[key] = append(groups[key], e)
	}
	sort.SliceStable(order, func(i, j int) bool {
		a, b := len(groups[order[i]]), len(groups[order[j]])
		if a != b {
			return a > b
		}
		return order[i] < order[j]
	})
	taken := map[string]bool{}
	for _, f := range rules.Noise {
		taken[f.ID] = true
	}
	for _, s := range rules.Sources {
		taken[s.ID] = true
	}
	var out []ProposedRule
	for _, normalised := range order {
		entries := groups[normalised]
		if len(entries) < minOccurrences {
			continue
		}
		sample := pyStrip(entries[0].Message)
		pattern := PatternFrom(normalised)
		if ValidatePattern(pattern, sample) != "" {
			continue
		}
		id := identifier(normalised, taken)
		taken[id] = true
		out = append(out, ProposedRule{
			ID: id, Label: label(normalised), Help: placeholderHelp, Match: pattern,
			Family: rules.SubsystemFamily(entries[0].Subsystem), Count: len(entries), Sample: sample,
		})
		if len(out) >= maxProposals {
			break
		}
	}
	return out
}

// RenderProposals renders the proposals for a human, "" when there are none.
func RenderProposals(proposals []ProposedRule) string {
	if len(proposals) == 0 {
		return ""
	}
	lines := []string{"Motifs récurrents non catalogués — propositions à relire avant tout ajout à rules.json :"}
	for _, p := range proposals {
		family := ""
		if p.Family != "" {
			family = ", famille " + p.Family
		}
		lines = append(lines, fmt.Sprintf(`- %s (×%d%s) : "%s"`, p.ID, p.Count, family, p.Match))
		lines = append(lines, "    exemple : "+p.Sample)
	}
	return strings.Join(lines, "\n")
}
