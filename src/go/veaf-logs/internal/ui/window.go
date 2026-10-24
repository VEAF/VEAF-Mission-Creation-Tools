//go:build windows

// Package ui is the walk window of veaf-logs (ADR 0022): what the Python
// viewer's ui/main_window.py shows, drawn with native Win32 controls in the
// dark theme. What it shows comes from internal/logview, tested on its own.
package ui

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
	"unsafe"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// refreshEvery is how often the window looks at the documents: the poll
// goroutines index and follow, the window only redraws what changed.
const refreshEvery = 100 * time.Millisecond

// dialogFilter is the open dialog's filter (DIALOG_FILTER in the Python).
const dialogFilter = "Journaux DCS (*.log;*.log.old;*.zip)|*.log;*.log.old;*.zip|Tous les fichiers (*.*)|*.*"

// Options are what the command line asks.
type Options struct {
	Paths []string
	// Smoke opens the paths, waits for their index, prints the timings and exits:
	// the CI's proof that the executable starts, and the measurement of J2.
	Smoke bool
	Start time.Time
}

type window struct {
	mw     *walk.MainWindow
	rules  *logcore.Rules
	strip  *logview.Strip[*logPane]
	tabs   *tabStrip
	stack  *walk.Composite
	msg    *walk.Label
	counts *walk.Label
	follow *walk.Label

	actFollow, actDetail *walk.Action

	fontFamily    string
	fontSize      int
	detailEnabled bool

	opts       Options
	smokeDone  bool
	closing    time.Time // when the smoke mode asked the window to close
	shownAt    time.Duration
	msgVersion int
}

// Run opens the window and returns the process exit code.
func Run(opts Options) int {
	dark.Init() // before any window
	rules, err := logcore.DefaultRules()
	if err != nil {
		fmt.Fprintln(os.Stderr, "veaf-logs:", err)
		return 1
	}
	app, err := walk.InitApp()
	if err != nil {
		fmt.Fprintln(os.Stderr, "veaf-logs:", err)
		return 1
	}
	w := &window{
		rules: rules, strip: logview.NewStrip[*logPane](), opts: opts,
		fontFamily: logview.DefaultFontFamily, fontSize: logview.DefaultFontSize, detailEnabled: true,
	}
	if err := w.create(); err != nil {
		fmt.Fprintln(os.Stderr, "veaf-logs:", err)
		return 1
	}
	w.shownAt = time.Since(opts.Start)

	paths := opts.Paths
	if len(paths) == 0 && !opts.Smoke {
		// The local journal by default, when the command line opens nothing.
		if p := currentDCSLog(); fileExists(p) {
			paths = []string{p}
		}
	}
	for _, p := range paths {
		w.openPath(p)
	}
	w.refreshStatus()

	exit := 0
	stop := make(chan struct{})
	go func() {
		ticker := time.NewTicker(refreshEvery)
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				w.mw.Synchronize(func() { w.tick(&exit) })
			}
		}
	}()
	app.Run()
	if !w.closing.IsZero() {
		fmt.Printf("closed=%.3fs\n", time.Since(w.closing).Seconds())
	}
	close(stop)
	for _, p := range w.strip.Items {
		p.doc.Close()
	}
	return exit
}

func (w *window) create() error {
	shortcut := func(mod walk.Modifiers, key walk.Key) Shortcut { return Shortcut{Modifiers: mod, Key: key} }
	var stripWidget *walk.CustomWidget
	err := MainWindow{
		AssignTo: &w.mw, Title: "veaf-logs — journaux DCS", Size: Size{Width: 1500, Height: 900},
		Background: SolidColorBrush{Color: dark.Window},
		Layout:     VBox{MarginsZero: true, SpacingZero: true},
		MenuItems: []MenuItem{
			Menu{Text: "&Fichier", Items: []MenuItem{
				Action{Text: "Ouvrir le journal DCS courant", Shortcut: shortcut(walk.ModControl, walk.KeyD), OnTriggered: w.openCurrentDCSLog},
				Action{Text: "Ouvrir un fichier…", Shortcut: shortcut(walk.ModControl, walk.KeyO), OnTriggered: w.openDialog},
				Separator{},
				Action{Text: "Fermer l'onglet", Shortcut: shortcut(walk.ModControl, walk.KeyW), OnTriggered: func() { w.closeTab(w.strip.Active) }},
				Action{Text: "Quitter", Shortcut: shortcut(walk.ModControl, walk.KeyQ), OnTriggered: func() { w.mw.Close() }},
			}},
			Menu{Text: "&Edition", Items: []MenuItem{
				Action{Text: "Copier", Shortcut: shortcut(walk.ModControl, walk.KeyC), OnTriggered: func() { w.copy(false) }},
				Action{Text: "Copier sans l'en-tête", Shortcut: shortcut(walk.ModControl|walk.ModShift, walk.KeyC), OnTriggered: func() { w.copy(true) }},
				Separator{},
				Action{Text: "Tout sélectionner", Shortcut: shortcut(walk.ModControl, walk.KeyA), OnTriggered: w.selectAll},
			}},
			Menu{Text: "&Affichage", Items: []MenuItem{
				Action{AssignTo: &w.actFollow, Text: "Suivre la fin du fichier", Checkable: true, Checked: true, Shortcut: shortcut(0, walk.KeyF), OnTriggered: w.toggleFollow},
				Action{Text: "Aller à la fin", Shortcut: shortcut(walk.ModControl, walk.KeyEnd), OnTriggered: w.scrollToEnd},
				Separator{},
				Action{Text: "Police…", OnTriggered: w.chooseFont},
				Action{Text: "Agrandir", Shortcut: shortcut(walk.ModControl, walk.KeyOEMPlus), OnTriggered: func() { w.zoom(1) }},
				Action{Text: "Réduire", Shortcut: shortcut(walk.ModControl, walk.KeyOEMMinus), OnTriggered: func() { w.zoom(-1) }},
				Action{Text: "Taille par défaut", Shortcut: shortcut(walk.ModControl, walk.Key0), OnTriggered: w.resetFont},
				Action{AssignTo: &w.actDetail, Text: "Panneau de détail", Checkable: true, Checked: true, Shortcut: shortcut(walk.ModControl, walk.KeyI), OnTriggered: w.toggleDetail},
			}},
		},
		Children: []Widget{
			tabStripWidget(&stripWidget, &w.tabs),
			Composite{
				AssignTo: &w.stack, AlwaysConsumeSpace: true, StretchFactor: 1000, // custom widgets are greedy: the strip must not share the room
				Layout: VBox{MarginsZero: true, SpacingZero: true}, Background: SolidColorBrush{Color: dark.Window},
			},
			Composite{
				Layout: HBox{Margins: Margins{Left: 6, Top: 2, Right: 6, Bottom: 2}}, Background: SolidColorBrush{Color: dark.Alternate},
				Children: []Widget{
					Label{AssignTo: &w.msg, Text: " ", TextColor: dark.Text},
					HSpacer{},
					Label{AssignTo: &w.counts, Text: logview.NoTabText, TextColor: dark.Text},
					Label{AssignTo: &w.follow, Text: " ", TextColor: dark.Dim},
				},
			},
		},
	}.Create()
	if err != nil {
		return err
	}
	w.tabs = newTabStrip(stripWidget, w.strip)
	w.tabs.onSelect = w.tabChanged
	w.tabs.onClose = w.closeTab

	// Ctrl+= zooms in too: Ctrl++ needs Shift on a French keyboard. And the
	// numeric keypad's + and -.
	for _, extra := range []struct {
		key  walk.Key
		step int
	}{{walk.KeyAdd, 1}, {walk.KeySubtract, -1}} {
		a := walk.NewAction()
		step := extra.step
		a.SetShortcut(walk.Shortcut{Modifiers: walk.ModControl, Key: extra.key})
		a.Triggered().Attach(func() { w.zoom(step) })
		w.mw.ShortcutActions().Add(a)
	}

	w.mw.ToolBar().SetVisible(false) // walk adds an empty tool bar to every main window
	if icon, err := walk.NewIconFromResourceId(2); err == nil {
		w.mw.SetIcon(icon)
	}
	dark.TitleBar(w.mw.Handle())
	dark.MenuBar(w.mw.Handle())
	return nil
}

// -- opening -----------------------------------------------------------------------------

func currentDCSLog() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Saved Games", "DCS", "Logs", "dcs.log")
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func (w *window) openCurrentDCSLog() {
	path := currentDCSLog()
	if !fileExists(path) {
		Message(w.mw, "Journal introuvable", "Aucun fichier à "+path+".\nUtilise « Ouvrir un fichier… ».")
		return
	}
	w.openPath(path)
}

func (w *window) openDialog() {
	home, _ := os.UserHomeDir()
	dlg := walk.FileDialog{
		Title: "Ouvrir un journal DCS", Filter: dialogFilter,
		InitialDirPath: filepath.Join(home, "Saved Games", "DCS", "Logs"),
		// Without it the dialog moves the process's current directory (ADR 0022).
		Flags: win.OFN_NOCHANGEDIR,
	}
	if ok, err := dlg.ShowOpenMultiple(w.mw); err != nil || !ok {
		return
	}
	for _, p := range dlg.FilePaths {
		w.openPath(p)
	}
}

// openPath opens a journal in a new tab; an archive first asks which of its
// logs, when it holds several.
func (w *window) openPath(path string) {
	path, _ = filepath.Abs(path)
	member := ""
	if logcore.IsArchive(path) {
		members, err := logcore.ArchiveMembers(path)
		switch {
		case err != nil:
			Message(w.mw, "Archive illisible", err.Error())
			return
		case len(members) == 0:
			Message(w.mw, "Archive", "Aucun journal dans "+filepath.Base(path)+".")
			return
		case len(members) == 1:
			member = members[0]
		default:
			i, ok := ChooseItem(w.mw, "Contenu de l'archive", filepath.Base(path)+" contient plusieurs fichiers :", members)
			if !ok {
				return
			}
			member = members[i]
		}
	}
	src, title, followable, err := openSource(path, member)
	if err != nil {
		if errors.Is(err, logcore.ErrUnavailable) {
			err = fmt.Errorf("%s : fichier introuvable", path)
		}
		Message(w.mw, "Ouverture impossible", err.Error())
		return
	}
	doc := logview.NewDoc(w.rules, src, followable)
	pane, err := newLogPane(w.stack, doc, title, path, w.font(), w.detailEnabled)
	if err != nil {
		doc.Close()
		Message(w.mw, "Ouverture impossible", err.Error())
		return
	}
	pane.onZoom = w.zoom
	pane.onCopy = func(messageOnly bool) { w.reportCopy(pane.Copy(messageOnly)) }
	pane.onChange = w.refreshStatus
	w.strip.Insert(pane, -1)
	doc.Start()
	w.tabChanged()
}

func (w *window) closeTab(i int) {
	pane, ok := w.strip.Remove(i)
	if !ok {
		return
	}
	pane.Close()
	w.tabChanged()
}

// -- the current tab -----------------------------------------------------------------------

func (w *window) current() *logPane {
	p, _ := w.strip.Current()
	return p
}

func (w *window) tabChanged() {
	current := w.current()
	for _, p := range w.strip.Items {
		p.root.SetVisible(p == current)
	}
	if current != nil {
		w.actFollow.SetChecked(current.follow)
		w.actFollow.SetEnabled(current.doc.Followable)
		current.Refresh()
	}
	w.tabs.Refresh()
	w.refreshStatus()
}

func (w *window) tick(exit *int) {
	for _, p := range w.strip.Items {
		if p.doc.Dirty() {
			p.Refresh()
			if p == w.current() {
				w.refreshStatus()
			}
		}
	}
	if w.opts.Smoke {
		w.smokeCheck(exit)
	}
}

func (w *window) refreshStatus() {
	p := w.current()
	if p == nil {
		w.counts.SetText(logview.NoTabText)
		w.follow.SetText("")
		return
	}
	st := p.doc.Status()
	w.counts.SetText(st.CountsText())
	w.follow.SetText("    " + logview.FollowText(p.doc.Followable, p.follow, st))
}

// showMessage writes a transient message on the left of the status bar.
func (w *window) showMessage(text string, d time.Duration) {
	w.msgVersion++
	version := w.msgVersion
	w.msg.SetText(text)
	time.AfterFunc(d, func() {
		w.mw.Synchronize(func() {
			if w.msgVersion == version {
				w.msg.SetText("")
			}
		})
	})
}

// -- menu actions ---------------------------------------------------------------------------

// copy copies what is selected where the user is looking: text selected in
// the detail panel stays a text copy, as in the Python; otherwise the rows.
func (w *window) copy(messageOnly bool) {
	p := w.current()
	if p == nil {
		return
	}
	if !messageOnly && win.GetFocus() == p.detail.Handle() {
		if start, end := p.detail.TextSelection(); end > start {
			win.SendMessage(p.detail.Handle(), win.WM_COPY, 0, 0)
			w.showMessage("Sélection copiée.", 2*time.Second)
			return
		}
	}
	w.reportCopy(p.Copy(messageOnly))
}

func (w *window) reportCopy(count int) {
	w.showMessage(logview.CopyReport(count), 2*time.Second)
}

func (w *window) selectAll() {
	p := w.current()
	if p == nil {
		return
	}
	if win.GetFocus() == p.detail.Handle() {
		p.detail.SetTextSelection(0, -1)
		return
	}
	for _, lv := range p.listViews {
		item := win.LVITEM{StateMask: win.LVIS_SELECTED, State: win.LVIS_SELECTED}
		win.SendMessage(lv, win.LVM_SETITEMSTATE, ^uintptr(0), uintptr(unsafe.Pointer(&item))) // -1: every item
	}
}

func (w *window) toggleFollow() {
	if p := w.current(); p != nil {
		p.SetFollow(w.actFollow.Checked())
	}
	w.refreshStatus()
}

func (w *window) scrollToEnd() {
	if p := w.current(); p != nil {
		p.ScrollToEnd()
	}
}

func (w *window) toggleDetail() {
	w.detailEnabled = w.actDetail.Checked()
	for _, p := range w.strip.Items {
		p.SetDetailEnabled(w.detailEnabled)
	}
}

func (w *window) font() *walk.Font {
	f, err := walk.NewFont(w.fontFamily, w.fontSize, 0)
	if err != nil {
		f, _ = walk.NewFont("Consolas", w.fontSize, 0)
	}
	return f
}

func (w *window) applyFont() {
	f := w.font()
	for _, p := range w.strip.Items {
		p.SetFont(f)
	}
	w.showMessage(fontLabel(w.fontFamily, w.fontSize), 2*time.Second)
}

func (w *window) zoom(step int) {
	size := logview.ClampFontSize(w.fontSize + step)
	if size == w.fontSize {
		return
	}
	w.fontSize = size
	w.applyFont()
}

func (w *window) resetFont() {
	w.fontFamily, w.fontSize = logview.DefaultFontFamily, logview.DefaultFontSize
	w.applyFont()
}

func (w *window) chooseFont() {
	family, size, ok := ChooseFont(w.mw, w.fontFamily, w.fontSize)
	if !ok {
		return
	}
	w.fontFamily, w.fontSize = family, size
	w.applyFont()
}

// -- smoke mode ----------------------------------------------------------------------------

func (w *window) smokeCheck(exit *int) {
	if w.smokeDone {
		return // closing: the ticks queued meanwhile must not report again
	}
	elapsed := time.Since(w.opts.Start)
	if len(w.strip.Items) == 0 {
		fmt.Fprintln(os.Stderr, "smoke: no tab opened")
		*exit = 2
		w.mw.Close()
		return
	}
	entries := 0
	for _, p := range w.strip.Items {
		st := p.doc.Status()
		if st.Indexing {
			if elapsed > 5*time.Minute {
				fmt.Fprintln(os.Stderr, "smoke: indexing timed out")
				*exit = 3
				w.mw.Close()
			}
			return
		}
		entries += st.Total
	}
	fmt.Printf("window=%.3fs indexed=%.3fs entries=%d tabs=%d\n", w.shownAt.Seconds(), elapsed.Seconds(), entries, len(w.strip.Items))
	w.smokeDone, w.closing = true, time.Now()
	w.mw.Close()
}
