//go:build windows

package ui

import (
	"sort"
	"strings"
	"syscall"
	"unsafe"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"
	"golang.org/x/sys/windows"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// Windows' message box and font chooser stay light even when Windows is dark
// (ADR 0022), so the viewer has its own, built from dark controls.

// darkenDialog applies the dark theme to a dialog built by walk.
func darkenDialog(dlg *walk.Dialog) {
	dark.TitleBar(dlg.Handle())
	dark.Controls(dlg.Handle())
}

// paragraphs keeps a label's blank lines: walk measures a label line by line
// and an empty line measures zero high, so the last lines of a text with
// paragraphs fell outside the box. A no-break space has a height, and walk does
// not trim it as it trims spaces.
func paragraphs(text string) string {
	lines := strings.Split(text, "\n")
	for i, l := range lines {
		if strings.TrimSpace(l) == "" {
			lines[i] = "\u00a0"
		}
	}
	return strings.Join(lines, "\n")
}

// Message shows a dark message box with an OK button. A warning or an error
// is said in its title, as the Python boxes do.
func Message(owner walk.Form, title, text string) {
	var dlg *walk.Dialog
	var ok *walk.PushButton
	err := Dialog{
		AssignTo: &dlg, Title: title, DefaultButton: &ok, CancelButton: &ok,
		MinSize: Size{Width: 360}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 16, Top: 16, Right: 16, Bottom: 12}},
		Children: []Widget{
			Label{Text: paragraphs(text), TextColor: dark.Text},
			Composite{Layout: HBox{MarginsZero: true}, Children: []Widget{
				HSpacer{},
				PushButton{AssignTo: &ok, Text: "OK", OnClicked: func() { dlg.Accept() }},
			}},
		},
	}.Create(owner)
	if err != nil {
		return
	}
	darkenDialog(dlg)
	dlg.Run()
}

// Prompt asks for a line of text (a profile's name); false when cancelled.
func Prompt(owner walk.Form, title, label, initial string) (string, bool) {
	var dlg *walk.Dialog
	var edit *walk.LineEdit
	var ok, cancel *walk.PushButton
	err := Dialog{
		AssignTo: &dlg, Title: title, DefaultButton: &ok, CancelButton: &cancel,
		MinSize: Size{Width: 380}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 12, Top: 12, Right: 12, Bottom: 12}},
		Children: []Widget{
			Label{Text: label, TextColor: dark.Text},
			LineEdit{AssignTo: &edit, Text: initial, TextColor: dark.Text},
			Composite{Layout: HBox{MarginsZero: true}, Children: []Widget{
				HSpacer{},
				PushButton{AssignTo: &ok, Text: "OK", OnClicked: func() { dlg.Accept() }},
				PushButton{AssignTo: &cancel, Text: "Annuler", OnClicked: func() { dlg.Cancel() }},
			}},
		},
	}.Create(owner)
	if err != nil {
		return "", false
	}
	edit.SetBackground(dark.WalkBrush(dark.Alternate))
	darkenDialog(dlg)
	edit.SetFocus()
	if dlg.Run() != walk.DlgCmdOK {
		return "", false
	}
	return edit.Text(), true
}

// Confirm asks yes or no, no being the default and holding the keyboard: the
// box can come to the front while the user types elsewhere, and a stray Enter
// or Space must not answer yes — not to a host key above all.
func Confirm(owner walk.Form, title, text string) bool {
	var dlg *walk.Dialog
	var yes, no *walk.PushButton
	err := Dialog{
		AssignTo: &dlg, Title: title, DefaultButton: &no, CancelButton: &no,
		MinSize: Size{Width: 360}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 16, Top: 16, Right: 16, Bottom: 12}},
		Children: []Widget{
			Label{Text: paragraphs(text), TextColor: dark.Text},
			Composite{Layout: HBox{MarginsZero: true}, Children: []Widget{
				HSpacer{},
				PushButton{AssignTo: &yes, Text: "Oui", OnClicked: func() { dlg.Accept() }},
				PushButton{AssignTo: &no, Text: "Non", OnClicked: func() { dlg.Cancel() }},
			}},
		},
	}.Create(owner)
	if err != nil {
		return false
	}
	darkenDialog(dlg)
	// walk focuses the first tab stop in z-order once laid out: put Non first,
	// where it stands on screen does not change.
	win.SetWindowPos(no.Handle(), win.HWND_TOP, 0, 0, 0, 0, win.SWP_NOMOVE|win.SWP_NOSIZE|win.SWP_NOACTIVATE)
	return dlg.Run() == walk.DlgCmdOK
}

// darkList is a one-column list for the dialogs. A Win32 list box would not
// take its colours (its WM_CTLCOLORLISTBOX never reached our subclass), so it
// is a table without header, darkened like the journal's.
type darkList struct {
	walk.TableModelBase
	items     []string
	tv        *walk.TableView
	listViews []win.HWND
}

func (l *darkList) RowCount() int                { return len(l.items) }
func (l *darkList) Value(row, _ int) interface{} { return l.items[row] }
func (l *darkList) declare(onChange, onActivate func()) TableView {
	return TableView{
		AssignTo: &l.tv, Model: l, HeaderHidden: true, LastColumnStretched: true,
		Columns: []TableViewColumn{{Title: ""}},
		StyleCell: func(s *walk.CellStyle) {
			s.BackgroundColor, s.TextColor = dark.Alternate, dark.Text
			if len(l.listViews) > 0 && win.SendMessage(l.listViews[0], win.LVM_GETITEMSTATE, uintptr(s.Row()), win.LVIS_SELECTED)&win.LVIS_SELECTED != 0 {
				s.BackgroundColor, s.TextColor = dark.Highlight, walk.RGB(0xff, 0xff, 0xff)
			}
		},
		OnCurrentIndexChanged: onChange,
		OnItemActivated:       onActivate,
	}
}

// darken finishes the list once created, and selects `current`.
func (l *darkList) darken(current int) {
	dark.Table(l.tv.Handle(), nil)
	dark.NoEdge(l.tv.Handle())
	for _, h := range dark.Children(l.tv.Handle()) {
		if dark.ClassName(h) == "SysListView32" {
			l.listViews = append(l.listViews, h)
			win.SendMessage(h, 0x1001 /* LVM_SETBKCOLOR */, 0, uintptr(dark.Alternate))
		}
	}
	if current >= 0 && current < len(l.items) {
		l.tv.SetCurrentIndex(current)
		// Scrolled now, before the list is laid out, the current font ended
		// out of view: again once the list has its size.
		l.tv.EnsureItemVisible(current)
		// Once: a later resize must not undo the user's scrolling.
		l.tv.SizeChanged().Once(func() {
			if i := l.tv.CurrentIndex(); i >= 0 {
				l.tv.EnsureItemVisible(i)
			}
		})
	}
}

// ChooseItem asks for one item of a list; false when cancelled. It is how an
// archive holding several logs asks which one to open.
func ChooseItem(owner walk.Form, title, label string, items []string) (int, bool) {
	var dlg *walk.Dialog
	var ok, cancel *walk.PushButton
	list := &darkList{items: items}
	err := Dialog{
		AssignTo: &dlg, Title: title, DefaultButton: &ok, CancelButton: &cancel,
		MinSize: Size{Width: 420, Height: 260}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 12, Top: 12, Right: 12, Bottom: 12}},
		Children: []Widget{
			Label{Text: label, TextColor: dark.Text},
			list.declare(nil, func() { dlg.Accept() }),
			Composite{Layout: HBox{MarginsZero: true}, Children: []Widget{
				HSpacer{},
				PushButton{AssignTo: &ok, Text: "OK", OnClicked: func() { dlg.Accept() }},
				PushButton{AssignTo: &cancel, Text: "Annuler", OnClicked: func() { dlg.Cancel() }},
			}},
		},
	}.Create(owner)
	if err != nil {
		return 0, false
	}
	darkenDialog(dlg)
	list.darken(0)
	if dlg.Run() != walk.DlgCmdOK || list.tv.CurrentIndex() < 0 {
		return 0, false
	}
	return list.tv.CurrentIndex(), true
}

// ChooseFont asks for a monospaced font and a size; false when cancelled.
func ChooseFont(owner walk.Form, family string, size int) (string, int, bool) {
	families := monospacedFamilies()
	if len(families) == 0 {
		return family, size, false
	}
	current := sort.SearchStrings(families, family)
	if current >= len(families) || families[current] != family {
		current = 0
	}
	var dlg *walk.Dialog
	var sizeEdit *walk.NumberEdit
	var sample *walk.Label
	var ok, cancel *walk.PushButton
	list := &darkList{items: families}
	update := func() {
		if list.tv == nil || sizeEdit == nil || sample == nil || list.tv.CurrentIndex() < 0 {
			return
		}
		if f, err := walk.NewFont(families[list.tv.CurrentIndex()], int(sizeEdit.Value()), 0); err == nil {
			sample.SetFont(f)
		}
	}
	err := Dialog{
		AssignTo: &dlg, Title: "Police du journal", DefaultButton: &ok, CancelButton: &cancel,
		MinSize: Size{Width: 460, Height: 440}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 12, Top: 12, Right: 12, Bottom: 12}},
		Children: []Widget{
			Label{Text: "Police (à chasse fixe) :", TextColor: dark.Text},
			list.declare(update, func() { dlg.Accept() }),
			Composite{Layout: HBox{MarginsZero: true}, Children: []Widget{
				Label{Text: "Taille :", TextColor: dark.Text},
				NumberEdit{AssignTo: &sizeEdit, Value: float64(size), MinValue: logview.MinFontSize, MaxValue: logview.MaxFontSize, Suffix: " pt", OnValueChanged: update, TextColor: dark.Text},
				HSpacer{},
			}},
			Label{AssignTo: &sample, Text: "2026-08-31 11:50:40.872 ERROR   SCRIPTING (Main): VEAF|W|log|123", TextColor: dark.Text},
			Composite{Layout: HBox{MarginsZero: true}, Children: []Widget{
				HSpacer{},
				PushButton{AssignTo: &ok, Text: "OK", OnClicked: func() { dlg.Accept() }},
				PushButton{AssignTo: &cancel, Text: "Annuler", OnClicked: func() { dlg.Cancel() }},
			}},
		},
	}.Create(owner)
	if err != nil {
		return family, size, false
	}
	sizeEdit.SetBackground(dark.WalkBrush(dark.Alternate))
	darkenDialog(dlg)
	list.darken(current)
	update()
	if dlg.Run() != walk.DlgCmdOK || list.tv.CurrentIndex() < 0 {
		return family, size, false
	}
	return families[list.tv.CurrentIndex()], logview.ClampFontSize(int(sizeEdit.Value())), true
}

// -- the monospaced fonts installed ---------------------------------------------

type logFont struct {
	height, width, escapement, orientation, weight int32
	italic, underline, strikeOut, charSet          byte
	outPrecision, clipPrecision, quality           byte
	pitchAndFamily                                 byte
	faceName                                       [32]uint16
}

var (
	enumFontFamiliesEx = windows.NewLazySystemDLL("gdi32.dll").NewProc("EnumFontFamiliesExW")
	fontsFound         map[string]bool
	fontCallback       = syscall.NewCallback(func(lf *logFont, _ uintptr, _ uint32, _ uintptr) uintptr {
		name := syscall.UTF16ToString(lf.faceName[:])
		// FIXED_PITCH, and not the vertical variants (`@MS Gothic`).
		if lf.pitchAndFamily&3 == 1 && !strings.HasPrefix(name, "@") {
			fontsFound[name] = true
		}
		return 1
	})
)

func monospacedFamilies() []string {
	fontsFound = map[string]bool{}
	hdc := win.GetDC(0)
	defer win.ReleaseDC(0, hdc)
	lf := logFont{charSet: 1 /* DEFAULT_CHARSET */}
	enumFontFamiliesEx.Call(uintptr(hdc), uintptr(unsafe.Pointer(&lf)), fontCallback, 0, 0)
	out := make([]string, 0, len(fontsFound))
	for name := range fontsFound {
		out = append(out, name)
	}
	sort.Strings(out)
	return out
}
