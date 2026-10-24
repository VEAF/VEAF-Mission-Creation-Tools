package analysis

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

// The `/bug` report block (`veaf_logs.report`): the doctor block, the excerpt,
// the catalogue and what the analysis could not explain, bounded to one
// Discord message — and saying so when something had to go. The reader half
// (`parse_report_block`) has no caller outside the Python's own tests and is not ported.

const (
	reportSchema = "veaf-logs-report/1"
	reportStart  = "=== VEAF-LOGS REPORT BEGIN ==="
	reportEnd    = "=== VEAF-LOGS REPORT END ==="

	// DiscordMessageLimit is how long a Discord message may be, code fence included.
	DiscordMessageLimit = 2000

	fenceOpen   = "```text"
	fenceClose  = "```"
	fenceEscape = "'''"

	minExcerptChars    = 200
	targetExcerptChars = 500
	excerptShrunk      = "excerpt (réduit)"
	maxRecompositions  = 3
)

var (
	reportSections   = []string{"doctor", "excerpt", "catalogue", "analysis", "proposals"}
	reportFieldOrder = []string{"schema", "generated", "excerpt.shown", "excerpt.selected", "excerpt.total", "excerpt.omitted", "excerpt.excluded", "catalogue.matched", "catalogue.uncatalogued", "proposals.count", "truncated"}
	reportDropOrder  = []string{"proposals", "analysis", "doctor.recent-errors", "catalogue"}
)

func fenceSafe(s string) string { return strings.ReplaceAll(s, "```", fenceEscape) }

func sectionOverhead(name string) int {
	return runeLen("--- "+name+" ---") + runeLen("--- "+name+" end ---") + 2
}

func describeExcluded(x Excerpt) string {
	var parts []string
	for _, k := range kindLabels {
		if keys := x.Excluded[k.kind]; len(keys) > 0 {
			parts = append(parts, k.kind+"="+strings.Join(keys, ","))
		}
	}
	if len(parts) == 0 {
		return "aucune"
	}
	return strings.Join(parts, "; ")
}

func compose(fields map[string]string, bodies map[string]string) string {
	lines := []string{reportStart}
	for _, name := range reportFieldOrder {
		if v, ok := fields[name]; ok {
			lines = append(lines, oneLine(name)+": "+oneLine(v))
		}
	}
	for _, name := range reportSections {
		if body := bodies[name]; body != "" {
			lines = append(lines, "--- "+name+" ---")
			lines = append(lines, pySplitLines(body)...)
			lines = append(lines, "--- "+name+" end ---")
		}
	}
	lines = append(lines, reportEnd)
	return strings.Join(lines, "\n")
}

// BuildReport assembles the block, without its fence: the commentary, the
// proposals, the doctor's recent errors and the catalogue go first, then the
// excerpt is shrunk to what is left, and `truncated` names what went. A block
// that still does not fit says by how much rather than being cut.
func BuildReport(r *Redactor, a Analysis, doctor *DiagnosticReport, maxChars int, now time.Time) string {
	fields := map[string]string{
		"schema":                 reportSchema,
		"generated":              now.UTC().Format("2006-01-02T15:04:05Z"),
		"excerpt.shown":          strconv.Itoa(len(a.Excerpt.Entries)),
		"excerpt.selected":       strconv.Itoa(a.Excerpt.Selected),
		"excerpt.total":          strconv.Itoa(a.Excerpt.TotalIndexed),
		"excerpt.omitted":        strconv.Itoa(a.Excerpt.Omitted),
		"excerpt.excluded":       describeExcluded(a.Excerpt),
		"catalogue.matched":      "aucun",
		"catalogue.uncatalogued": strconv.Itoa(a.UncataloguedTotal),
		"proposals.count":        strconv.Itoa(len(a.Proposals)),
	}
	if len(a.Matches) > 0 {
		ids := make([]string, len(a.Matches))
		for i, m := range a.Matches {
			ids[i] = m.ID
		}
		fields["catalogue.matched"] = strings.Join(ids, ",")
	}
	model := a.Commentary
	if model == "" {
		model = a.ModelError
	}
	proposals := make([]string, len(a.Proposals))
	for i, p := range a.Proposals {
		proposals[i] = p.ID + ": " + p.Match
	}
	bodies := map[string]string{
		"excerpt":   a.Excerpt.Text(),
		"catalogue": RenderCatalogue(a.Matches),
		"analysis":  model,
		"proposals": strings.Join(proposals, "\n"),
	}
	if doctor != nil {
		bodies["doctor"] = doctor.Block()
	}
	for k, v := range bodies {
		bodies[k] = fenceSafe(v)
	}

	budget := maxChars - runeLen(fenceOpen) - runeLen(fenceClose) - 2
	var dropped []string
	fields["truncated"] = "non"
	noteDropped := func(names []string) {
		fields["truncated"] = "retiré pour tenir dans un message : " + strings.Join(names, ", ")
	}
	composed := func() string { return r.Redact(compose(fields, bodies)) }
	withoutExcerpt := func() int {
		saved := bodies["excerpt"]
		bodies["excerpt"] = ""
		n := runeLen(composed())
		bodies["excerpt"] = saved
		return n
	}
	roomForExcerpt := func() int { return budget - withoutExcerpt() - sectionOverhead("excerpt") }
	drop := func(name string) bool {
		if name == "doctor.recent-errors" {
			if doctor == nil || len(doctor.RecentErrors) == 0 || !strings.Contains(bodies["doctor"], errorsStart) {
				return false
			}
			bodies["doctor"] = fenceSafe(DiagnosticReport{Fields: doctor.Fields}.Block())
			return true
		}
		if bodies[name] == "" {
			return false
		}
		bodies[name] = ""
		return true
	}

	for _, name := range reportDropOrder {
		if roomForExcerpt() >= targetExcerptChars {
			break
		}
		if drop(name) {
			dropped = append(dropped, name)
			noteDropped(dropped)
		}
	}

	if runeLen(bodies["excerpt"]) > roomForExcerpt() {
		noteDropped(append(append([]string(nil), dropped...), excerptShrunk))
		shrunk := false
		for i := 0; i < maxRecompositions; i++ {
			room := roomForExcerpt()
			if room < minExcerptChars {
				shrunk = false
				break
			}
			candidate := a.Excerpt.Rebound(room)
			if len(candidate.Entries) == 0 {
				shrunk = false
				break
			}
			shrunk = true
			bodies["excerpt"] = fenceSafe(candidate.Text())
			fields["excerpt.shown"] = strconv.Itoa(len(candidate.Entries))
			fields["excerpt.omitted"] = strconv.Itoa(candidate.Omitted)
			if runeLen(composed()) <= budget {
				break
			}
		}
		if shrunk {
			dropped = append(dropped, excerptShrunk)
		} else {
			bodies["excerpt"] = ""
			fields["excerpt.shown"] = "0"
			fields["excerpt.omitted"] = strconv.Itoa(a.Excerpt.Selected)
			dropped = append(dropped, "excerpt")
		}
		noteDropped(dropped)
	}

	for _, name := range reportDropOrder {
		if runeLen(composed()) <= budget {
			break
		}
		if drop(name) {
			dropped = append(dropped, name)
			noteDropped(dropped)
		}
	}

	block := composed()
	if runeLen(block) > budget {
		block = composed()
		for i := 0; i < maxRecompositions; i++ {
			fields["truncated"] = overflowNote(runeLen(block), budget, dropped)
			recomposed := composed()
			if runeLen(recomposed) == runeLen(block) {
				return recomposed
			}
			block = recomposed
		}
	}
	return block
}

func overflowNote(length, budget int, dropped []string) string {
	note := fmt.Sprintf("OUI — %d caractères pour une limite de %d : à coller en deux messages", length, budget)
	if len(dropped) > 0 {
		return note + " ; retiré : " + strings.Join(dropped, ", ")
	}
	return note
}

// ToClipboard wraps a block in the code fence it travels in.
func ToClipboard(block string) string { return fenceOpen + "\n" + block + "\n" + fenceClose }
