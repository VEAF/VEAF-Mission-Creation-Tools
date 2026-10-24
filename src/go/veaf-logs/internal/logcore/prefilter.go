package logcore

import (
	"bytes"
	"regexp"
	"regexp/syntax"
)

// pattern is a compiled regexp plus a cheap necessary condition: literals of
// which at least one must appear in any match. Go's regexp is a backtracker on
// short inputs and costs ~1 µs per try; a bytes.Contains costs a few ns and
// rejects the vast majority of lines, which is what the catalogue's patterns
// (mostly plain phrases) are for. The prefilter never changes the result: it
// only skips the regexp when no match is possible.
type pattern struct {
	re   *regexp.Regexp
	lits [][]byte // empty: no prefilter available
}

func newPattern(expr string) (*pattern, error) {
	re, err := regexp.Compile(expr)
	if err != nil {
		return nil, err
	}
	p := &pattern{re: re}
	if tree, err := syntax.Parse(expr, syntax.Perl); err == nil {
		if lits, ok := requiredLiterals(tree); ok {
			p.lits = lits
		}
	}
	return p, nil
}

func (p *pattern) possible(b []byte) bool {
	if len(p.lits) == 0 {
		return true
	}
	for _, l := range p.lits {
		if bytes.Contains(b, l) {
			return true
		}
	}
	return false
}

func (p *pattern) Match(b []byte) bool {
	return p.possible(b) && p.re.Match(b)
}

func (p *pattern) FindSubmatchIndex(b []byte) []int {
	if !p.possible(b) {
		return nil
	}
	return p.re.FindSubmatchIndex(b)
}

func (p *pattern) SubexpIndex(name string) int { return p.re.SubexpIndex(name) }

// requiredLiterals returns literals such that every match of the expression
// contains at least one of them, or false when none can be established.
func requiredLiterals(re *syntax.Regexp) ([][]byte, bool) {
	switch re.Op {
	case syntax.OpLiteral:
		if re.Flags&syntax.FoldCase != 0 || len(re.Rune) == 0 {
			return nil, false
		}
		return [][]byte{[]byte(string(re.Rune))}, true
	case syntax.OpCapture, syntax.OpPlus:
		return requiredLiterals(re.Sub[0])
	case syntax.OpRepeat:
		if re.Min >= 1 {
			return requiredLiterals(re.Sub[0])
		}
	case syntax.OpConcat:
		var best [][]byte
		bestLen := 0
		for _, sub := range re.Sub {
			lits, ok := requiredLiterals(sub)
			if !ok {
				continue
			}
			shortest := len(lits[0])
			for _, l := range lits {
				if len(l) < shortest {
					shortest = len(l)
				}
			}
			if shortest > bestLen {
				best, bestLen = lits, shortest
			}
		}
		return best, best != nil
	case syntax.OpAlternate:
		var all [][]byte
		for _, sub := range re.Sub {
			lits, ok := requiredLiterals(sub)
			if !ok {
				return nil, false
			}
			all = append(all, lits...)
		}
		return all, len(all) > 0
	}
	return nil, false
}
