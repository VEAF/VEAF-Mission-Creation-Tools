//go:build windows

package ui

import (
	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

var searchModes = []logcore.Mode{logcore.ModePlain, logcore.ModeGlob, logcore.ModeRegex}

// searchBar is the live criterion (ui/panels.py, SearchBar): field, mode,
// inversion, case, its own context span, "add to the filter", the error of an
// invalid regex — which applies nothing until it is valid.
type searchBar struct {
	field    *walk.LineEdit
	mode     *walk.ComboBox
	context  *walk.NumberEdit
	add      *walk.PushButton
	errLabel *walk.Label
	invert   painted
	caseSens painted
	invertOn bool
	caseOn   bool
	common   int

	changed      func()
	addRequested func()
}

func (s *searchBar) declare() Composite {
	labels := make([]string, len(searchModes))
	for i, m := range searchModes {
		labels[i] = m.Label()
	}
	s.invert = painted{text: "≠", color: dark.Text, back: dark.Button, center: true, onClick: func() { s.invertOn = !s.invertOn; s.showToggles(); s.onChange() }}
	s.caseSens = painted{text: "Aa", color: dark.Text, back: dark.Button, center: true, onClick: func() { s.caseOn = !s.caseOn; s.showToggles(); s.onChange() }}
	return Composite{
		Layout: HBox{Margins: Margins{Left: 6, Top: 4, Right: 6, Bottom: 4}}, Background: SolidColorBrush{Color: dark.Window},
		Children: []Widget{
			LineEdit{AssignTo: &s.field, CueBanner: "Rechercher…  (Ctrl+F)", TextColor: dark.Text, StretchFactor: 1000, OnTextChanged: s.onChange},
			ComboBox{
				AssignTo: &s.mode, Model: labels, CurrentIndex: 0, MaxSize: Size{Width: 90}, OnCurrentIndexChanged: s.onChange,
				ToolTipText: "Texte : recherche littérale.\nJokers : * (n'importe quelle suite), ? (un caractère) ; le point reste littéral.\nRegex : expression régulière complète.",
			},
			declarePainted(&s.invert, 28, 22),
			declarePainted(&s.caseSens, 32, 22),
			NumberEdit{
				AssignTo: &s.context, Prefix: "±", MinValue: 0, MaxValue: 999, MinSize: Size{Width: 100}, MaxSize: Size{Width: 100}, TextColor: dark.Text, OnValueChanged: s.onChange,
				ToolTipText: "Lignes gardées de part et d'autre des résultats de cette recherche.\nEntre parenthèses : la valeur commune réglée dans le panneau latéral.",
			},
			PushButton{AssignTo: &s.add, Text: "Ajouter au filtre", ToolTipText: "Cumuler ce critère avec les filtres déjà actifs", OnClicked: func() { s.addRequested() }},
			Label{AssignTo: &s.errLabel, TextColor: walk.RGB(0xff, 0x6b, 0x6b)},
		},
	}
}

// finish darkens the bar once created.
func (s *searchBar) finish() {
	s.field.SetBackground(dark.WalkBrush(dark.Alternate))
	s.context.SetBackground(dark.WalkBrush(dark.Alternate))
	dark.Theme(s.field.Handle(), "DarkMode_CFD")
	dark.Theme(s.mode.Handle(), "DarkMode_CFD")
	dark.ListColors(s.mode.Handle())
	dark.Theme(s.add.Handle(), "DarkMode_Explorer")
	s.invert.widget.SetToolTipText("Masquer les lignes qui correspondent")
	s.caseSens.widget.SetToolTipText("Respecter la casse")
	s.showToggles()
	s.SetCommonContext(0)
}

func (s *searchBar) showToggles() {
	for _, t := range []struct {
		p  *painted
		on bool
	}{{&s.invert, s.invertOn}, {&s.caseSens, s.caseOn}} {
		if t.on {
			t.p.SetBack(dark.Highlight)
		} else {
			t.p.SetBack(dark.Button)
		}
	}
}

// Current is the live criterion.
func (s *searchBar) Current() logcore.TextFilter {
	t := logcore.TextFilter{Pattern: s.field.Text(), Mode: searchModes[max(0, s.mode.CurrentIndex())], CaseSensitive: s.caseOn, Invert: s.invertOn}
	if v := int(s.context.Value()); v > 0 {
		t.ContextLines = &v
	}
	return t
}

// SetCommonContext shows the common span where the field sets none.
func (s *searchBar) SetCommonContext(lines int) {
	s.common = lines
	if s.context.Value() == 0 {
		s.context.SetSuffix(" " + logview.SearchContextHint(lines))
	} else {
		s.context.SetSuffix("")
	}
}

// Clear empties the field (a profile loaded, a criterion added).
func (s *searchBar) Clear() { s.field.SetText("") }

// onChange validates before passing on: a regex being typed is often invalid,
// its error is shown without rebuilding the view.
func (s *searchBar) onChange() {
	if s.field == nil || s.mode == nil || s.context == nil || s.errLabel == nil {
		return // still being built
	}
	s.SetCommonContext(s.common)
	t := s.Current()
	if _, err := logcore.CompilePattern(t.Pattern, t.Mode, t.CaseSensitive); err != nil {
		s.errLabel.SetText(err.Error())
		return
	}
	s.errLabel.SetText("")
	if s.changed != nil {
		s.changed()
	}
}

// -- chips ---------------------------------------------------------------------------

// chipRow shows the saved text criteria, one removable button each.
type chipRow struct {
	box    *walk.Composite
	remove func(i int)
}

func (c *chipRow) declare() Composite {
	return Composite{AssignTo: &c.box, Visible: false, Layout: HBox{Margins: Margins{Left: 6, Bottom: 4}}, Background: SolidColorBrush{Color: dark.Window}}
}

// Refresh rebuilds the chips from the saved criteria.
func (c *chipRow) Refresh(filters []logcore.TextFilter) {
	for c.box.Children().Len() > 0 {
		c.box.Children().At(0).Dispose()
	}
	var widgets []Widget
	for i, t := range filters {
		i := i
		widgets = append(widgets, PushButton{Text: t.Describe() + "  ✕", ToolTipText: "Retirer ce filtre", OnClicked: func() { c.remove(i) }})
	}
	if len(widgets) > 0 {
		widgets = append(widgets, HSpacer{})
		for _, w := range widgets {
			w.Create(NewBuilder(c.box))
		}
		for _, h := range dark.Children(c.box.Handle()) {
			if dark.ClassName(h) == "Button" {
				dark.Theme(h, "DarkMode_Explorer")
			}
		}
	}
	c.box.SetVisible(len(filters) > 0)
}
