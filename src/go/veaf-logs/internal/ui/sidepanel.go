//go:build windows

package ui

import (
	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// sideWidth is the panel's width at start, and when shown again after being
// collapsed by its handle (SIDE_WIDTH in the Python).
const sideWidth = 320

// offColor is the colour of a hidden category.
var offColor = walk.RGB(0x5a, 0x61, 0x69)

// sidePanel is the left column (ui/panels.py, SidePanel): the two context
// spans and the levels, sources and noise families with their three states.
// The states live in the window's filter set; the panel shows and edits them.
type sidePanel struct {
	root          *walk.ScrollView
	contextLines  *walk.NumberEdit
	searchContext *walk.NumberEdit
	groups        []*stateGroup

	rules   *logcore.Rules
	filters *logcore.FilterSet
	changed func()
	syncing bool
}

type stateGroup struct {
	panel *sidePanel
	kind  string
	title string
	box   *walk.Composite
	rows  map[string]*catRow
	order []string
	all   [3]painted
}

type catRow struct {
	group  *stateGroup
	cat    logview.Category
	comp   *walk.Composite
	button painted
	span   *walk.NumberEdit
}

func newSidePanel(rules *logcore.Rules, filters *logcore.FilterSet, changed func()) *sidePanel {
	p := &sidePanel{rules: rules, filters: filters, changed: changed}
	for _, g := range []struct{ kind, title string }{{"levels", "Niveaux"}, {"sources", "Sources"}, {"noise", "Bruit"}} {
		p.groups = append(p.groups, &stateGroup{panel: p, kind: g.kind, title: g.title, rows: map[string]*catRow{}})
	}
	return p
}

// declare declares the panel in the window's layout.
func (p *sidePanel) declare() ScrollView {
	span := func(assign **walk.NumberEdit, label, hint string, onChange func()) Composite {
		return Composite{
			Layout: HBox{MarginsZero: true}, Background: SolidColorBrush{Color: dark.Window},
			Children: []Widget{
				Label{Text: label, TextColor: dark.Text},
				NumberEdit{AssignTo: assign, MinValue: 0, MaxValue: 200, Suffix: " lignes", ToolTipText: hint, TextColor: dark.Text, MinSize: Size{Width: 110}, MaxSize: Size{Width: 110}, OnValueChanged: onChange},
				HSpacer{},
			},
		}
	}
	children := []Widget{
		Label{Text: logview.Legend, TextColor: dark.Dim},
		// Two distinct contexts, named so they are not confused: the categories in ◐ on one side, the search results on the other.
		span(&p.contextLines, "Contexte des catégories : ±",
			"Nombre de lignes gardées de part et d'autre d'une ligne retenue,\npour les catégories en mode contexte (◐).", p.contextChanged),
		span(&p.searchContext, "Contexte de recherche : ±",
			"Nombre de lignes gardées autour de chaque résultat de recherche.\nElles restent soumises aux filtres : une ligne masquée le reste.", p.contextChanged),
	}
	for _, g := range p.groups {
		children = append(children, g.declare())
	}
	children = append(children, VSpacer{StretchFactor: 1000}) // custom widgets are greedy: the rows must not share the room
	return ScrollView{
		AssignTo: &p.root, HorizontalFixed: true, MinSize: Size{Width: 300},
		Background: SolidColorBrush{Color: dark.Window},
		Layout:     VBox{Margins: Margins{Left: 6, Top: 6, Right: 6, Bottom: 6}},
		Children:   children,
	}
}

func (g *stateGroup) declare() Composite {
	buttons := []Widget{Label{Text: g.title, TextColor: dark.Text, Font: Font{Bold: true}}, HSpacer{StretchFactor: 1000}}
	for i, s := range []struct {
		label string
		state logcore.State
	}{{"tout", logcore.StateOn}, {"contexte", logcore.StateContext}, {"rien", logcore.StateOff}} {
		state := s.state
		g.all[i] = painted{text: s.label, color: dark.Text, back: dark.Button, center: true, onClick: func() { g.setAll(state) }}
		buttons = append(buttons, declarePainted(&g.all[i], 64, 20))
	}
	return Composite{
		Layout: VBox{Margins: Margins{Top: 6}, Spacing: 0}, Background: SolidColorBrush{Color: dark.Window},
		Children: []Widget{
			Composite{Layout: HBox{MarginsZero: true}, Background: SolidColorBrush{Color: dark.Window}, Children: buttons},
			Composite{AssignTo: &g.box, Layout: VBox{MarginsZero: true, SpacingZero: true}, Background: SolidColorBrush{Color: dark.Window}},
		},
	}
}

// finish darkens the panel once created.
func (p *sidePanel) finish() {
	p.contextLines.SetBackground(dark.WalkBrush(dark.Alternate))
	p.searchContext.SetBackground(dark.WalkBrush(dark.Alternate))
	dark.Theme(p.root.Handle(), "DarkMode_Explorer")
}

// Refresh updates the categories from a journal's counters without touching
// the states chosen: rows are kept, only their count changes.
func (p *sidePanel) Refresh(c logview.Counts) {
	p.groups[0].refresh(logview.LevelCategories(p.rules, c.Levels))
	p.groups[1].refresh(logview.SourceCategories(p.rules, c.Sources, c.SourceOrder))
	p.groups[2].refresh(logview.NoiseCategories(p.rules, c.Noise))
	p.Apply()
}

func (g *stateGroup) refresh(cats []logview.Category) {
	seen := map[string]bool{}
	for _, c := range cats {
		seen[c.Key] = true
		if row, ok := g.rows[c.Key]; ok {
			row.cat = c
			continue
		}
		row := &catRow{group: g, cat: c}
		row.button.onClick = row.cycle
		err := Composite{
			AssignTo: &row.comp, Layout: HBox{MarginsZero: true, Spacing: 4}, MaxSize: Size{Height: 22},
			Background: SolidColorBrush{Color: dark.Window},
			Children: []Widget{
				declarePainted(&row.button, 0, 22),
				NumberEdit{
					AssignTo: &row.span, Prefix: "±", MinValue: 0, MaxValue: 999, MinSize: Size{Width: 90}, MaxSize: Size{Width: 90}, Visible: false,
					TextColor: dark.Text, OnValueChanged: row.spanChanged,
					ToolTipText: "Lignes gardées de part et d'autre, pour cette catégorie.\nÀ zéro, elle suit la valeur commune.",
				},
			},
		}.Create(NewBuilder(g.box))
		if err != nil {
			continue
		}
		row.span.SetBackground(dark.WalkBrush(dark.Alternate))
		g.rows[c.Key] = row
		g.order = append(g.order, c.Key)
	}
	kept := g.order[:0]
	for _, key := range g.order {
		if seen[key] {
			kept = append(kept, key)
			continue
		}
		g.rows[key].comp.Dispose()
		delete(g.rows, key)
	}
	g.order = kept
}

// Apply shows the filter set's states and spans, without echoing them back.
func (p *sidePanel) Apply() {
	p.syncing = true
	defer func() { p.syncing = false }()
	f := p.filters
	p.contextLines.SetValue(float64(f.ContextLines))
	p.searchContext.SetValue(float64(f.SearchContextLines))
	for _, g := range p.groups {
		for _, key := range g.order {
			g.rows[key].show()
		}
	}
}

func (r *catRow) show() {
	f := r.group.panel.filters
	state := logview.StateOf(*f, r.group.kind, r.cat.Key)
	color := parseColor(r.cat.Color, dark.Text)
	if state == logcore.StateOff {
		color = offColor
	}
	r.button.Set(logview.RowText(r.cat, state), color, r.cat.Color != "", state == logcore.StateContext)
	r.button.widget.SetToolTipText(logview.RowTooltip(r.cat, state))
	context := state == logcore.StateContext
	if r.span.Visible() != context {
		r.span.SetVisible(context)
	}
	if context {
		var own *int
		if v, ok := f.ContextSpans[logcore.SpanKey(r.group.kind, r.cat.Key)]; ok {
			own = &v
			r.span.SetValue(float64(v))
		} else {
			r.span.SetValue(0)
		}
		r.span.SetSuffix(logview.SpanSuffix(own, f.ContextLines))
	}
}

func (r *catRow) cycle() {
	f := r.group.panel.filters
	f.SetState(r.group.kind, r.cat.Key, logview.NextState(logview.StateOf(*f, r.group.kind, r.cat.Key)))
	r.show()
	r.group.panel.changed()
}

func (r *catRow) spanChanged() {
	p := r.group.panel
	if p.syncing {
		return
	}
	var own *int
	if v := int(r.span.Value()); v > 0 {
		own = &v
	}
	p.filters.SetSpan(r.group.kind, r.cat.Key, own)
	r.span.SetSuffix(logview.SpanSuffix(own, p.filters.ContextLines))
	p.changed()
}

func (g *stateGroup) setAll(s logcore.State) {
	logview.SetAll(g.panel.filters, g.kind, g.order, s)
	for _, key := range g.order {
		g.rows[key].show()
	}
	g.panel.changed()
}

func (p *sidePanel) contextChanged() {
	if p.syncing {
		return
	}
	p.filters.ContextLines = int(p.contextLines.Value())
	p.filters.SearchContextLines = int(p.searchContext.Value())
	p.Apply()
	p.changed()
}
