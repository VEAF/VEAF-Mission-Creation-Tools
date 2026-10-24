package analysis

import (
	"fmt"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// *Explain* (`veaf_logs.analysis`): the catalogue first, ignorance admitted,
// the model last — each kept apart per block, so a verified sentence is never
// mistaken for a generated one.

const (
	catalogueHeading    = "── CATALOGUE VÉRIFIÉ (texte de rules.json, repris tel quel) ──"
	modelHeading        = "── MISE EN CONTEXTE PAR LE MODÈLE (généré, à vérifier) ──"
	uncataloguedHeading = "── NON CATALOGUÉ ──"
	proposalsHeading    = "── PROPOSITIONS DE RÈGLES ──"
	uncataloguedMark    = "motif non catalogué"
	notRequested        = "Analyse en ligne non demandée."

	maxUncataloguedShown = 10
)

// Analysis is one *Explain* run: the excerpt, what the catalogue said, what the model added.
type Analysis struct {
	Excerpt           Excerpt
	Matches           []CatalogueMatch
	Uncatalogued      []string // messages, capped at maxUncataloguedShown
	UncataloguedTotal int
	Proposals         []ProposedRule
	Commentary        string // what the model said
	ModelError        string // why it said nothing
}

// Text renders the whole answer, verified material first and visually apart.
func (a Analysis) Text() string {
	blocks := []string{a.Excerpt.Text(), catalogueHeading, RenderCatalogue(a.Matches)}
	if len(a.Uncatalogued) > 0 {
		lines := make([]string, len(a.Uncatalogued))
		for i, m := range a.Uncatalogued {
			lines[i] = "- " + uncataloguedMark + " : " + m
		}
		listed := strings.Join(lines, "\n")
		if hidden := a.UncataloguedTotal - len(a.Uncatalogued); hidden > 0 {
			listed += fmt.Sprintf("\n- … et %d autres lignes non cataloguées", hidden)
		}
		blocks = append(blocks, uncataloguedHeading, listed)
	}
	model := a.Commentary
	if model == "" {
		model = a.ModelError
	}
	if model == "" {
		model = notRequested
	}
	blocks = append(blocks, modelHeading, model)
	if rendered := RenderProposals(a.Proposals); rendered != "" {
		blocks = append(blocks, proposalsHeading, rendered)
	}
	return strings.Join(blocks, "\n\n")
}

// WithModel is the same analysis carrying another model section.
func (a Analysis) WithModel(commentary, err string) Analysis {
	a.Commentary, a.ModelError = commentary, err
	return a
}

// Analyse explains the view, offline: the catalogue layer, the uncatalogued
// records and the proposals. The model layer is asked separately (Online).
func Analyse(r *Redactor, store *logcore.Store, rules *logcore.Rules, f *logcore.FilterSet, visible []int, maxChars int) (Analysis, error) {
	x, err := BuildExcerpt(r, store, f, visible, maxChars)
	if err != nil {
		return Analysis{}, err
	}
	unknown := Uncatalogued(rules, x)
	a := Analysis{
		Excerpt: x, Matches: MatchCatalogue(rules, x),
		UncataloguedTotal: len(unknown), Proposals: ProposeRules(rules, x),
	}
	for i, e := range unknown {
		if i == maxUncataloguedShown {
			break
		}
		a.Uncatalogued = append(a.Uncatalogued, e.Message)
	}
	return a, nil
}
