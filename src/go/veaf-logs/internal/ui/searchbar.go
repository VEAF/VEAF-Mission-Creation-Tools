//go:build windows

package ui

import (
	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

var searchModes = []logcore.Mode{logcore.ModePlain, logcore.ModeGlob, logcore.ModeRegex}

// searchBar is the live criterion (ui/panels.py, SearchBar): field, mode,
// inversion, case, its own context span, "add to the filter", the error of an
// invalid regex — which applies nothing until it is valid.
type searchBar struct {
	field   *walk.LineEdit
	mode    *walk.ComboBox
	context *walk.NumberEdit
	// the edit field inside context, which shows "(N)" at zero (dark.Overlay)
	contextEdit win.HWND
	add         *walk.PushButton
	errLabel    *walk.Label
	invert      painted
	caseSens    painted
	invertOn    bool
	caseOn      bool
	common      int

	changed      func()
	addRequested func()
}

func (s *searchBar) declare() Composite {
	labels := make([]string, len(searchModes))
	for i, m := range searchModes {
		labels[i] = m.Label()
	}
	s.invert = painted{text: "≠", color: dark.Text, back: dark.Button, center: true, frame: true, onClick: func() { s.invertOn = !s.invertOn; s.showToggles(); s.onChange() }}
	s.caseSens = painted{text: "Aa", color: dark.Text, back: dark.Button, center: true, frame: true, onClick: func() { s.caseOn = !s.caseOn; s.showToggles(); s.onChange() }}
	return Composite{
		Layout: HBox{Margins: Margins{Left: 6, Top: 4, Right: 6, Bottom: 4}}, MaxSize: Size{Height: barHeight + 8}, Background: SolidColorBrush{Color: dark.Window},
		Children: []Widget{
			LineEdit{AssignTo: &s.field, CueBanner: "Rechercher…  (Ctrl+F)", TextColor: dark.Text, StretchFactor: 1000, OnTextChanged: s.onChange},
			ComboBox{
				AssignTo: &s.mode, Model: labels, CurrentIndex: 0, MaxSize: Size{Width: 90}, OnCurrentIndexChanged: s.onChange,
				ToolTipText: "Texte : recherche littérale.\nJokers : * (n'importe quelle suite), ? (un caractère) ; le point reste littéral.\nRegex : expression régulière complète.",
			},
			declarePainted(&s.invert, 28, barHeight),
			declarePainted(&s.caseSens, 32, barHeight),
			NumberEdit{
				AssignTo: &s.context, Prefix: "±", MinValue: 0, MaxValue: 999, MinSize: Size{Width: 72}, MaxSize: Size{Width: 72}, TextColor: dark.Text, OnValueChanged: s.onChange,
				ToolTipText: "Lignes gardées de part et d'autre des résultats de cette recherche.\nEntre parenthèses : la valeur commune réglée dans le panneau latéral.",
			},
			barButton(PushButton{AssignTo: &s.add, Text: "Ajouter au filtre", ToolTipText: "Cumuler ce critère avec les filtres déjà actifs", OnClicked: func() { s.addRequested() }}),
			Label{AssignTo: &s.errLabel, TextColor: walk.RGB(0xff, 0x6b, 0x6b)},
		},
	}
}

// finish darkens the bar once created.
func (s *searchBar) finish() {
	s.field.SetBackground(dark.WalkBrush(dark.Alternate))
	s.context.SetBackground(dark.WalkBrush(dark.Alternate))
	dark.Theme(s.mode.Handle(), "DarkMode_CFD")
	dark.ListColors(s.mode.Handle())
	s.invert.widget.SetToolTipText("Masquer les lignes qui correspondent")
	s.caseSens.widget.SetToolTipText("Respecter la casse")
	s.showToggles()
	for _, h := range dark.Children(s.context.Handle()) {
		if dark.ClassName(h) == "Edit" {
			s.contextEdit = h
			dark.Overlay(h, func() string {
				if s.context.Value() != 0 {
					return ""
				}
				return logview.SearchContextHint(s.common)
			})
		}
	}
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

// SetCommonContext shows the common span where the field sets none: "(2)" in
// place of the field's "±0", as the Python's special value text.
func (s *searchBar) SetCommonContext(lines int) {
	s.common = lines
	if s.contextEdit != 0 {
		win.InvalidateRect(s.contextEdit, nil, true)
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
	return Composite{AssignTo: &c.box, Visible: false, Layout: HBox{Margins: Margins{Left: 6, Bottom: 4}}, MaxSize: Size{Height: barHeight + 4}, Background: SolidColorBrush{Color: dark.Window}}
}

// Refresh rebuilds the chips from the saved criteria.
func (c *chipRow) Refresh(filters []logcore.TextFilter) {
	for c.box.Children().Len() > 0 {
		c.box.Children().At(0).Dispose()
	}
	var widgets []Widget
	for i, t := range filters {
		i := i
		widgets = append(widgets, barButton(PushButton{Text: t.Describe() + "  ✕", ToolTipText: "Retirer ce filtre", OnClicked: func() { c.remove(i) }}))
	}
	if len(widgets) > 0 {
		widgets = append(widgets, HSpacer{})
		for _, w := range widgets {
			w.Create(NewBuilder(c.box))
		}
		dark.Controls(c.box.Handle())
	}
	c.box.SetVisible(len(filters) > 0)
}
