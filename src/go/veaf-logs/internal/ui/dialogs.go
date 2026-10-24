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
	for _, h := range dark.Children(dlg.Handle()) {
		switch dark.ClassName(h) {
		case "Button":
			dark.Theme(h, "DarkMode_Explorer")
		case "Edit":
			dark.Theme(h, "DarkMode_CFD")
		case "ComboBox":
			dark.Theme(h, "DarkMode_CFD")
			dark.ListColors(h)
		case "ListBox":
			dark.Theme(h, "DarkMode_Explorer")
			dark.ListColors(win.GetParent(h))
		}
	}
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
			Label{Text: text, TextColor: dark.Text},
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

// ChooseItem asks for one item of a list; false when cancelled. It is how an
// archive holding several logs asks which one to open.
func ChooseItem(owner walk.Form, title, label string, items []string) (int, bool) {
	var dlg *walk.Dialog
	var list *walk.ListBox
	var ok, cancel *walk.PushButton
	err := Dialog{
		AssignTo: &dlg, Title: title, DefaultButton: &ok, CancelButton: &cancel,
		MinSize: Size{Width: 420, Height: 260}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 12, Top: 12, Right: 12, Bottom: 12}},
		Children: []Widget{
			Label{Text: label, TextColor: dark.Text},
			ListBox{AssignTo: &list, Model: items, CurrentIndex: 0, OnItemActivated: func() { dlg.Accept() }},
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
	if dlg.Run() != walk.DlgCmdOK || list.CurrentIndex() < 0 {
		return 0, false
	}
	return list.CurrentIndex(), true
}

// ChooseFont asks for a monospaced font and a size; false when cancelled.
func ChooseFont(owner walk.Form, family string, size int) (string, int, bool) {
	families := monospacedFamilies()
	current := sort.SearchStrings(families, family)
	if current >= len(families) || families[current] != family {
		current = 0
	}
	var dlg *walk.Dialog
	var list *walk.ListBox
	var sizeEdit *walk.NumberEdit
	var sample *walk.Label
	var ok, cancel *walk.PushButton
	update := func() {
		if list == nil || sizeEdit == nil || sample == nil || list.CurrentIndex() < 0 {
			return
		}
		if f, err := walk.NewFont(families[list.CurrentIndex()], int(sizeEdit.Value()), 0); err == nil {
			sample.SetFont(f)
		}
	}
	err := Dialog{
		AssignTo: &dlg, Title: "Police du journal", DefaultButton: &ok, CancelButton: &cancel,
		MinSize: Size{Width: 460, Height: 420}, Background: SolidColorBrush{Color: dark.Window},
		Layout: VBox{Margins: Margins{Left: 12, Top: 12, Right: 12, Bottom: 12}},
		Children: []Widget{
			Label{Text: "Police (à chasse fixe) :", TextColor: dark.Text},
			ListBox{AssignTo: &list, Model: families, CurrentIndex: current, OnCurrentIndexChanged: update, OnItemActivated: func() { dlg.Accept() }},
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
	if err != nil || len(families) == 0 {
		return family, size, false
	}
	sizeEdit.SetBackground(dark.WalkBrush(dark.Alternate))
	darkenDialog(dlg)
	update()
	if dlg.Run() != walk.DlgCmdOK || list.CurrentIndex() < 0 {
		return family, size, false
	}
	return families[list.CurrentIndex()], logview.ClampFontSize(int(sizeEdit.Value())), true
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
