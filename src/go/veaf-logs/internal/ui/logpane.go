//go:build windows

package ui

import (
	"regexp"
	"strconv"
	"strings"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// progressThreshold is the size from which the indexing shows a progress bar:
// below it the journal is indexed before anyone could read the bar.
const progressThreshold = 4 << 20

// logPane is one tab: the table, the detail panel, the indexing progress.
type logPane struct {
	doc      *logview.Doc
	title    string
	location string
	path     string // for the session; the remote path for a remote journal
	member   string // archive member, "" for a plain file
	remote   string // `server/instance` of a remote journal, "" for a local one

	root        *walk.Composite
	tv          *walk.TableView
	detail      *walk.TextEdit
	progressRow *walk.Composite
	progress    *walk.ProgressBar
	model       *tableModel
	listViews   []win.HWND

	shownRows, resets int
	follow            bool
	detailEnabled     bool
	patterns          []*regexp.Regexp

	font, bold         *walk.Font
	charWidth          int
	messageWidth       int // last width set by us, in pixels; the user's own is kept
	userWidth          bool
	copyWhole, copyMsg *walk.Action

	onZoom   func(step int)
	onCopy   func(messageOnly bool)
	onChange func()
}

type tableModel struct {
	walk.TableModelBase
	pane *logPane
}

func (m *tableModel) RowCount() int { return m.pane.shownRows }

func (m *tableModel) Value(row, col int) interface{} {
	e, ok := m.pane.doc.Entry(row)
	if !ok {
		return ""
	}
	if col == logview.ColMessage && len(m.pane.patterns) > 0 {
		return "" // drawn by styleCell, with its highlights
	}
	return logview.Cell(e, col)
}

func newLogPane(parent walk.Container, doc *logview.Doc, title, location string, font *walk.Font, detailEnabled bool) (*logPane, error) {
	p := &logPane{doc: doc, title: title, location: location, follow: doc.Followable, detailEnabled: detailEnabled}
	p.model = &tableModel{pane: p}
	columns := make([]TableViewColumn, logview.ColumnCount)
	for i := range columns {
		columns[i] = TableViewColumn{Title: logview.Headers[i], Width: 600}
		if i < logview.ColMessage {
			columns[i].Width = logview.FixedWidths[i]
		}
		if i == logview.ColLine {
			columns[i].Alignment = AlignFar
		}
	}
	err := Composite{
		AssignTo: &p.root, Layout: VBox{MarginsZero: true, SpacingZero: true}, AlwaysConsumeSpace: true,
		Background: SolidColorBrush{Color: dark.Window},
		Children: []Widget{
			VSplitter{
				Background: SolidColorBrush{Color: dark.Window},
				Children: []Widget{
					TableView{
						AssignTo: &p.tv, MultiSelection: true, Columns: columns, Model: p.model,
						StyleCell: p.styleCell, StretchFactor: 5,
						OnCurrentIndexChanged:    p.refreshDetail,
						OnSelectedIndexesChanged: p.selectionChanged,
					},
					TextEdit{
						AssignTo: &p.detail, ReadOnly: true, HScroll: true, VScroll: true, StretchFactor: 1,
						TextColor: dark.Text, Background: SolidColorBrush{Color: dark.Alternate}, Visible: false,
					},
				},
			},
			Composite{
				AssignTo: &p.progressRow, Visible: false, Background: SolidColorBrush{Color: dark.Window},
				Layout: HBox{Margins: Margins{Left: 6, Top: 2, Right: 6, Bottom: 2}},
				Children: []Widget{
					ProgressBar{AssignTo: &p.progress, MaxValue: 100, MaxSize: Size{Height: 16}},
					PushButton{Text: "Interrompre l'indexation", OnClicked: doc.Cancel},
				},
			},
		},
	}.Create(NewBuilder(parent))
	if err != nil {
		return nil, err
	}
	dark.Table(p.tv.Handle(), nil)
	dark.NoEdge(p.tv.Handle())
	for _, h := range dark.Children(p.tv.Handle()) {
		if dark.ClassName(h) == "SysListView32" {
			p.listViews = append(p.listViews, h)
			dark.Subclass(h, p.wheel)
			dark.NoEdge(h)
		}
	}
	dark.Theme(p.detail.Handle(), "DarkMode_Explorer")
	dark.NoEdge(p.detail.Handle())
	p.detail.SetVisible(false) // shown once a row is selected
	dark.SplitterHandles(p.root.Handle())
	dark.ProgressBar(p.progress.Handle())
	dark.Controls(p.progressRow.Handle())
	p.buildContextMenu()
	p.SetFont(font)
	return p, nil
}

// -- drawing ---------------------------------------------------------------------------

func (p *logPane) selected(row int) bool {
	if len(p.listViews) == 0 {
		return false
	}
	return win.SendMessage(p.listViews[0], win.LVM_GETITEMSTATE, uintptr(row), win.LVIS_SELECTED)&win.LVIS_SELECTED != 0
}

// styleCell colours a cell from the catalogue and draws the message with its
// highlights. A cell drawn here skips walk's default drawing, selection
// included, so the selection is drawn here too.
func (p *logPane) styleCell(s *walk.CellStyle) {
	e, ok := p.doc.Entry(s.Row())
	if !ok {
		return
	}
	style := p.doc.Rules.LevelStyle(e.Level)
	bg := dark.Window
	if style.Background != "" {
		bg = parseColor(style.Background, bg)
	}
	fg := parseColor(logview.CellColor(p.doc.Rules, e, s.Col()), dark.Text)
	if p.selected(s.Row()) {
		bg, fg = dark.Highlight, walk.RGB(0xff, 0xff, 0xff)
	}
	s.BackgroundColor, s.TextColor = bg, fg
	if style.Weight >= 600 && p.bold != nil {
		s.Font = p.bold
	}
	if s.Col() != logview.ColMessage || len(p.patterns) == 0 {
		return
	}
	c := s.Canvas()
	if c == nil {
		return
	}
	b := s.BoundsPixels()
	hdc := c.HDC()
	cell := win.RECT{Left: int32(b.X), Top: int32(b.Y), Right: int32(b.X + b.Width), Bottom: int32(b.Y + b.Height)}
	win.FillRect(hdc, &cell, dark.Brush(bg))
	font := p.font
	if s.Font != nil {
		font = s.Font
	}
	win.SelectObject(hdc, win.HGDIOBJ(fontHandle(font, p.tv.DPI())))
	win.SetBkMode(hdc, win.TRANSPARENT)
	text := logview.Cell(e, logview.ColMessage)
	x := b.X + 4
	at := 0
	draw := func(part string, highlight bool) {
		w := textWidth(hdc, part)
		r := win.RECT{Left: int32(x), Top: cell.Top, Right: int32(x + w + 1), Bottom: cell.Bottom}
		color := fg
		if highlight {
			win.FillRect(hdc, &r, dark.Brush(walk.RGB(0x7a, 0x5c, 0x00)))
			color = walk.RGB(0xff, 0xff, 0xff)
		}
		win.SetTextColor(hdc, win.COLORREF(color))
		drawText(hdc, part, &r, win.DT_LEFT|win.DT_SINGLELINE|win.DT_VCENTER|win.DT_NOPREFIX)
		x += w
	}
	for _, span := range logview.HighlightSpans(text, p.patterns) {
		draw(text[at:span[0]], false)
		draw(text[span[0]:span[1]], true)
		at = span[1]
	}
	draw(text[at:], false)
}

// wheel turns Ctrl + wheel over the table into a zoom.
func (p *logPane) wheel(_ win.HWND, msg uint32, wp, _ uintptr) (uintptr, bool) {
	if msg != win.WM_MOUSEWHEEL || wp&0x0008 == 0 { // MK_CONTROL
		return 0, false
	}
	if delta := int16(wp >> 16); delta > 0 {
		p.onZoom(1)
	} else if delta < 0 {
		p.onZoom(-1)
	}
	return 0, true
}

// SetFont applies the journal's font to the table and the detail panel; the
// row height follows it.
func (p *logPane) SetFont(font *walk.Font) {
	p.font = font
	p.bold, _ = walk.NewFont(font.Family(), font.PointSize(), walk.FontBold)
	p.tv.SetFont(font)
	p.detail.SetFont(font)
	hdc := win.GetDC(0)
	win.SelectObject(hdc, win.HGDIOBJ(fontHandle(font, p.tv.DPI())))
	p.charWidth = textWidth(hdc, "0")
	win.ReleaseDC(0, hdc)
	// The fixed columns in characters of the journal's font: the Python's
	// pixel widths cut the time and the level as soon as the font grows.
	dpi := p.tv.DPI()
	for i, chars := range logview.FixedChars {
		// Two characters and the list view's own cell padding (6 px a side at 96 DPI) of margin.
		p.tv.Columns().At(i).SetWidth(((chars+2)*p.charWidth)*96/dpi + 12)
	}
	// A new font redefines what a right width is: the column is ours again.
	p.userWidth = false
	p.syncMessageWidth()
}

// SetPatterns sets the highlighted patterns (the text filters in force).
func (p *logPane) SetPatterns(patterns []*regexp.Regexp) {
	p.patterns = patterns
	p.tv.Invalidate()
}

func (p *logPane) syncMessageWidth() {
	col := p.tv.Columns().At(logview.ColMessage)
	dpi := p.tv.DPI()
	current := col.Width() * dpi / 96
	if p.messageWidth > 0 && current != p.messageWidth && !p.userWidth {
		p.userWidth = true // dragged by hand: kept
	}
	if p.userWidth {
		return
	}
	fixed := 0
	for i := 0; i < logview.ColMessage; i++ {
		fixed += p.tv.Columns().At(i).Width() * dpi / 96
	}
	available := p.tv.ClientBoundsPixels().Width - fixed
	w := logview.MessageWidth(p.doc.MaxMessageLength(), p.charWidth, available)
	if w != p.messageWidth {
		p.messageWidth = w
		col.SetWidth(w * 96 / dpi)
		p.messageWidth = col.Width() * dpi / 96
	}
}

// -- following the document ---------------------------------------------------------------

// Refresh brings the table up to date with the document: rows appended are
// inserted, rows replaced (a rotation, new filters) reload the table.
func (p *logPane) Refresh() {
	rows, resets := p.doc.Rows(), p.doc.Resets()
	switch {
	case resets != p.resets || rows < p.shownRows:
		p.shownRows, p.resets = rows, resets
		p.model.PublishRowsReset()
	case rows > p.shownRows:
		old := p.shownRows
		p.shownRows = rows
		if old > 0 {
			p.model.PublishRowChanged(old - 1) // its stack trace may have arrived with the new lines
		}
		p.model.PublishRowsInserted(old, rows-1)
	case rows > 0:
		p.model.PublishRowChanged(rows - 1)
	}
	if p.follow && rows > 0 {
		p.tv.EnsureItemVisible(rows - 1)
	}
	st := p.doc.Status()
	showProgress := st.Indexing && st.Size > progressThreshold
	if p.progressRow.Visible() != showProgress {
		p.progressRow.SetVisible(showProgress)
	}
	if showProgress {
		p.progress.SetValue(st.Percent())
	}
	p.syncMessageWidth()
}

// SetFollow switches the follow mode; switching it on goes to the end.
func (p *logPane) SetFollow(on bool) {
	p.follow = on && p.doc.Followable
	if p.follow {
		p.ScrollToEnd()
	}
}

// ScrollToEnd shows the last row.
func (p *logPane) ScrollToEnd() {
	if p.shownRows > 0 {
		p.tv.EnsureItemVisible(p.shownRows - 1)
	}
}

// -- detail, selection, copy ------------------------------------------------------------

// SetDetailEnabled shows or hides the detail panel.
func (p *logPane) SetDetailEnabled(on bool) {
	p.detailEnabled = on
	p.refreshDetail()
}

// refreshDetail shows the current entry whole, whatever its level.
func (p *logPane) refreshDetail() {
	row := p.tv.CurrentIndex()
	e, ok := p.doc.Entry(row)
	if !p.detailEnabled || row < 0 || !ok || len(p.tv.SelectedIndexes()) == 0 {
		p.detail.SetVisible(false)
		p.detail.SetText("")
		return
	}
	// The edit control wants Windows line ends.
	p.detail.SetText(strings.ReplaceAll(logview.Text(e), "\n", "\r\n"))
	p.detail.SetVisible(true)
}

func (p *logPane) selectionChanged() {
	whole, message := logview.ContextMenuLabels(len(p.tv.SelectedIndexes()))
	p.copyWhole.SetText(whole)
	p.copyMsg.SetText(message)
	p.refreshDetail()
	if p.onChange != nil {
		p.onChange()
	}
}

func (p *logPane) buildContextMenu() {
	menu, err := walk.NewMenu()
	if err != nil {
		return
	}
	p.copyWhole = walk.NewAction()
	p.copyWhole.Triggered().Attach(func() { p.onCopy(false) })
	p.copyMsg = walk.NewAction()
	p.copyMsg.Triggered().Attach(func() { p.onCopy(true) })
	menu.Actions().Add(p.copyWhole)
	menu.Actions().Add(p.copyMsg)
	whole, message := logview.ContextMenuLabels(1)
	p.copyWhole.SetText(whole)
	p.copyMsg.SetText(message)
	p.tv.SetContextMenu(menu)
}

// Copy puts the selected entries on the clipboard and returns how many.
func (p *logPane) Copy(messageOnly bool) int {
	entries := p.doc.Entries(p.tv.SelectedIndexes())
	if len(entries) == 0 {
		return 0
	}
	walk.Clipboard().SetText(strings.ReplaceAll(logview.CopyText(entries, messageOnly), "\n", "\r\n"))
	return len(entries)
}

// Close stops the document and destroys the widgets.
func (p *logPane) Close() {
	p.doc.Close()
	p.root.Dispose()
}

// -- helpers ------------------------------------------------------------------------------

func parseColor(hex string, fallback walk.Color) walk.Color {
	if len(hex) != 7 || hex[0] != '#' {
		return fallback
	}
	v, err := strconv.ParseUint(hex[1:], 16, 32)
	if err != nil {
		return fallback
	}
	return walk.RGB(byte(v>>16), byte(v>>8), byte(v))
}

// openSource opens a journal: an archive member or a followed file.
func openSource(path, member string) (logcore.Follower, string, bool, error) {
	if logcore.IsArchive(path) {
		a, err := logcore.OpenArchive(path, member)
		if err != nil {
			return nil, "", false, err
		}
		return a, a.DisplayName(), false, nil
	}
	t, err := logcore.OpenTailer(path)
	if err != nil {
		return nil, "", false, err
	}
	return t, baseName(path), true, nil
}

func baseName(path string) string {
	if i := strings.LastIndexAny(path, `\/`); i >= 0 {
		return path[i+1:]
	}
	return path
}
