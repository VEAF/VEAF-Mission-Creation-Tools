//go:build windows

package ui

import (
	"fmt"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// sideWidth is the panel's width (SIDE_WIDTH in the Python), kept when the
// window is resized. The scroll view is HorizontalFixed — walk then reserves its
// vertical scroll bar, and lays it out at its content's width — so the width is
// given to the content, through the legend.
const sideWidth = 320

// Heights of a group's parts, at 96 DPI. A walk CustomWidget is greedy in both
// directions and walk ignores a maximum across a box, so a group made of them
// would share the panel's whole height with its neighbours: fit pins each group
// to the sum of these, and the spacer under the groups takes what is left.
const (
	groupTop    = 8  // gap above a group
	titleHeight = 20 // a group's title
	headHeight  = 22 // its three buttons
	rowHeight   = 22 // a category
)

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
	comp  *walk.Composite
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
				NumberEdit{AssignTo: assign, MinValue: 0, MaxValue: 200, Suffix: " lignes", ToolTipText: hint, TextColor: dark.Text, MinSize: Size{Width: 80}, MaxSize: Size{Width: 80}, OnValueChanged: onChange},
				HSpacer{},
			},
		}
	}
	children := []Widget{
		Label{Text: logview.Legend, TextColor: dark.Dim, MinSize: Size{Width: sideWidth - 12}}, // 12: the margins
		// Two distinct contexts, named so they are not confused: the categories in ◐ on one side, the search results on the other.
		span(&p.contextLines, "Contexte des catégories : ±",
			"Nombre de lignes gardées de part et d'autre d'une ligne retenue,\npour les catégories en mode contexte (◐).", p.contextChanged),
		span(&p.searchContext, "Contexte de recherche : ±",
			"Nombre de lignes gardées autour de chaque résultat de recherche.\nElles restent soumises aux filtres : une ligne masquée le reste.", p.contextChanged),
	}
	for _, g := range p.groups {
		children = append(children, g.declare())
	}
	children = append(children, VSpacer{}) // the room the groups leave, at the bottom (see fit)
	return ScrollView{
		AssignTo: &p.root, HorizontalFixed: true, MinSize: Size{Width: 300},
		Background: SolidColorBrush{Color: dark.Window},
		Layout:     VBox{Margins: Margins{Left: 6, Top: 6, Right: 6, Bottom: 6}},
		Children:   children,
	}
}

func (g *stateGroup) declare() Composite {
	// As in the Python: the title on its own line, the three buttons at their width on the left.
	var buttons []Widget
	for i, s := range []struct {
		label string
		width int
		state logcore.State
	}{{"tout", 40, logcore.StateOn}, {"contexte", 64, logcore.StateContext}, {"rien", 40, logcore.StateOff}} {
		state := s.state
		g.all[i] = painted{text: s.label, color: dark.Text, back: dark.Button, center: true, frame: true, onClick: func() { g.setAll(state) }}
		buttons = append(buttons, declarePainted(&g.all[i], s.width, headHeight))
	}
	buttons = append(buttons, HSpacer{})
	head := groupTop + titleHeight + headHeight
	return Composite{
		AssignTo: &g.comp, MinSize: Size{Height: head}, MaxSize: Size{Height: head},
		Layout: VBox{Margins: Margins{Top: groupTop}, SpacingZero: true}, Background: SolidColorBrush{Color: dark.Window},
		Children: []Widget{
			Label{Text: g.title, TextColor: dark.Text, MinSize: Size{Height: titleHeight}, MaxSize: Size{Height: titleHeight}},
			Composite{Layout: HBox{MarginsZero: true, Spacing: 2}, MaxSize: Size{Height: headHeight}, Background: SolidColorBrush{Color: dark.Window}, Children: buttons},
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
			AssignTo: &row.comp, Layout: HBox{MarginsZero: true, Spacing: 4}, MaxSize: Size{Height: rowHeight},
			Background: SolidColorBrush{Color: dark.Window},
			Children: []Widget{
				declarePainted(&row.button, 0, rowHeight),
				NumberEdit{
					AssignTo: &row.span, Prefix: "±", MinValue: 0, MaxValue: 999, MinSize: Size{Width: 72}, MaxSize: Size{Width: 72}, Visible: false,
					TextColor: dark.Text, OnValueChanged: row.spanChanged,
					ToolTipText: "Lignes gardées de part et d'autre, pour cette catégorie.\nÀ zéro, elle suit la valeur commune.",
				},
			},
		}.Create(NewBuilder(g.box))
		if err != nil {
			continue
		}
		row.span.SetBackground(dark.WalkBrush(dark.Alternate))
		dark.Controls(row.comp.Handle())
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
	g.fit()
}

// fit pins the group to the height of its title, buttons and rows (see groupTop).
func (g *stateGroup) fit() {
	rows := len(g.order) * rowHeight
	g.box.SetVisible(rows > 0)
	if rows > 0 {
		_ = g.box.SetMinMaxSize(walk.Size{Height: rows}, walk.Size{Height: rows})
	}
	total := groupTop + titleHeight + headHeight + rows
	_ = g.comp.SetMinMaxSize(walk.Size{Height: total}, walk.Size{Height: total})
}

// layoutError reports a group that walk did not lay out at the height fit gave
// it: taller, a short journal spreads its few categories over the whole panel;
// shorter, its last rows are cut off. The smoke mode checks it.
func (p *sidePanel) layoutError() error {
	for _, g := range p.groups {
		want := walk.IntFrom96DPI(groupTop+titleHeight+headHeight+len(g.order)*rowHeight, g.comp.DPI())
		if got := g.comp.HeightPixels(); got < want-1 || got > want+1 {
			return fmt.Errorf("side panel: group %s is %d px high for %d px of content", g.title, got, want)
		}
	}
	return nil
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
