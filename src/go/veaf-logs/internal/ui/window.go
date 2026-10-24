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
	"sync"
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

// panelRefreshEvery spaces the side panel's rebuilds while a big journal is
// indexed: rebuilding at every slice costs more than the indexing (PANEL_REFRESH_MS).
const panelRefreshEvery = 400 * time.Millisecond

// dialogFilter is the open dialog's filter (DIALOG_FILTER in the Python).
const dialogFilter = "Journaux DCS (*.log;*.log.old;*.zip)|*.log;*.log.old;*.zip|Tous les fichiers (*.*)|*.*"

// Options are what the command line asks.
type Options struct {
	Paths []string
	// Smoke opens the paths, waits for their index, prints the timings and
	// exits, leaving the user's session alone: the CI's proof that the
	// executable starts, and the measurements.
	Smoke bool
	Start time.Time
}

type window struct {
	mw     *walk.MainWindow
	rules  *logcore.Rules
	strip  *logview.Strip[*logPane]
	tabs   *tabStrip
	stack  *walk.Composite
	side   *sidePanel
	search *searchBar
	chips  *chipRow
	msg    *walk.Label
	counts *walk.Label
	follow *walk.Label

	profileBox     *walk.ComboBox
	profileDelete  *walk.PushButton
	filtersToggle  painted
	zoomOut        painted
	zoomIn         painted
	profiles       *logview.ProfileStore
	profileChoices []string

	actFollow, actDetail, actFilters *walk.Action

	// filters are the saved filters in force; the live search criterion is added on top.
	filters       logcore.FilterSet
	fontFamily    string
	fontSize      int
	detailEnabled bool

	session  logview.Session
	restore  *logview.Restore  // the session's remote tabs, reopened one at a time once the window shows
	restored map[*logPane]bool // tabs the restore opened: another one in front was chosen, and keeps the front
	panelAt  time.Time

	// rulesFile is the catalogue the Règles menu opens and F5 reloads, "" until opened.
	rulesFile string

	// connMu guards what the remote connections hand back to the window: a
	// source opened while the window closes must still be closed by someone.
	connMu    sync.Mutex
	closed    bool
	unclaimed map[*logcore.RemoteSource]bool
	done      chan struct{} // closed once the window is gone: a pending host key question gives up

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
		rules: rules, strip: logview.NewStrip[*logPane](), opts: opts, session: logview.NewSession(),
		restore: logview.NewRestore(), restored: map[*logPane]bool{}, unclaimed: map[*logcore.RemoteSource]bool{}, done: make(chan struct{}),
	}
	if !opts.Smoke {
		w.session = logview.LoadSession(logview.SessionPath())
	}
	w.filters = w.session.FilterSet()
	w.fontFamily, w.fontSize, w.detailEnabled = w.session.FontFamily, w.session.FontSize, w.session.DetailVisible
	w.profiles = logview.NewProfileStore(rules, "")
	if err := w.create(); err != nil {
		fmt.Fprintln(os.Stderr, "veaf-logs:", err)
		return 1
	}
	w.shownAt = time.Since(opts.Start)
	w.restoreSession()

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
	close(w.done)
	for _, p := range w.strip.Items {
		p.doc.Close()
	}
	if w.rulesFile != "" {
		os.Remove(w.rulesFile)
	}
	return exit
}

func (w *window) create() error {
	shortcut := func(mod walk.Modifiers, key walk.Key) Shortcut { return Shortcut{Modifiers: mod, Key: key} }
	var stripWidget *walk.CustomWidget
	w.side = newSidePanel(w.rules, &w.filters, w.sideChanged)
	w.search = &searchBar{changed: w.applyFilters, addRequested: w.addCurrentFilter}
	w.chips = &chipRow{remove: w.removeFilter}
	w.filtersToggle = painted{text: "☰ Filtres", color: dark.Text, back: dark.Button, center: true, onClick: func() { w.setFiltersPanel(!w.side.root.Visible()) }}
	w.zoomOut = painted{text: "A−", color: dark.Text, back: dark.Button, center: true, onClick: func() { w.zoom(-1) }}
	w.zoomIn = painted{text: "A+", color: dark.Text, back: dark.Button, center: true, onClick: func() { w.zoom(1) }}

	err := MainWindow{
		AssignTo: &w.mw, Title: "veaf-logs — journaux DCS", Size: Size{Width: 1500, Height: 900},
		Background: SolidColorBrush{Color: dark.Window},
		Layout:     VBox{MarginsZero: true, SpacingZero: true},
		MenuItems: []MenuItem{
			Menu{Text: "&Fichier", Items: []MenuItem{
				Action{Text: "Ouvrir le journal DCS courant", Shortcut: shortcut(walk.ModControl, walk.KeyD), OnTriggered: w.openCurrentDCSLog},
				Action{Text: "Ouvrir un fichier…", Shortcut: shortcut(walk.ModControl, walk.KeyO), OnTriggered: w.openDialog},
				Action{Text: "Ouvrir un journal distant…", Shortcut: shortcut(walk.ModControl|walk.ModShift, walk.KeyO), OnTriggered: w.openRemoteDialog},
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
				Action{AssignTo: &w.actDetail, Text: "Panneau de détail", Checkable: true, Checked: w.detailEnabled, Shortcut: shortcut(walk.ModControl, walk.KeyI), OnTriggered: w.toggleDetail},
				Action{AssignTo: &w.actFilters, Text: "Panneau des filtres", Checkable: true, Checked: w.session.FiltersVisible, Shortcut: shortcut(walk.ModControl, walk.KeyB), OnTriggered: func() { w.setFiltersPanel(w.actFilters.Checked()) }},
				Separator{},
				Action{Text: "Tout afficher (réinitialiser les filtres)", Shortcut: shortcut(walk.ModControl, walk.KeyR), OnTriggered: w.resetFilters},
				Action{Text: "Chercher", Shortcut: shortcut(walk.ModControl, walk.KeyF), OnTriggered: func() { w.search.field.SetFocus() }},
			}},
			Menu{Text: "&Profils", Items: []MenuItem{
				Action{Text: "Enregistrer sous…", Shortcut: shortcut(walk.ModControl, walk.KeyS), OnTriggered: w.saveProfile},
				Action{Text: "Supprimer le profil courant", OnTriggered: w.deleteProfile},
			}},
			Menu{Text: "&Règles", Items: []MenuItem{
				Action{Text: "Recharger le catalogue", Shortcut: shortcut(0, walk.KeyF5), OnTriggered: w.reloadRules},
				Action{Text: "Ouvrir rules.json", OnTriggered: w.openRulesFile},
			}},
		},
		Children: []Widget{
			HSplitter{
				Background: SolidColorBrush{Color: dark.Window}, StretchFactor: 1000,
				Children: []Widget{
					w.side.declare(),
					Composite{
						Layout: VBox{MarginsZero: true, SpacingZero: true}, Background: SolidColorBrush{Color: dark.Window}, StretchFactor: 4,
						Children: []Widget{
							w.profileBar(),
							w.search.declare(),
							w.chips.declare(),
							tabStripWidget(&stripWidget, &w.tabs),
							Composite{
								AssignTo: &w.stack, AlwaysConsumeSpace: true, StretchFactor: 1000, // custom widgets are greedy: the strip must not share the room
								Layout: VBox{MarginsZero: true, SpacingZero: true}, Background: SolidColorBrush{Color: dark.Window},
							},
						},
					},
				},
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
	w.search.finish()
	w.side.finish()
	dark.SplitterHandles(w.mw.Handle())
	w.finishProfileBar()
	w.side.Apply()
	w.chips.Refresh(w.filters.TextFilters)
	w.setFiltersPanel(w.session.FiltersVisible)
	w.mw.Closing().Attach(func(*bool, walk.CloseReason) {
		w.saveSession()
		w.closeConnections()
		w.restore.Abandon()
	})
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
	w.openPath(path, "")
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
		w.openPath(p, "")
	}
}

// openPath opens a journal in a new tab; an archive first asks which of its
// logs, when it holds several and no member is given.
func (w *window) openPath(path, member string) *logPane {
	path, _ = filepath.Abs(path)
	if logcore.IsArchive(path) && member == "" {
		members, err := logcore.ArchiveMembers(path)
		switch {
		case err != nil:
			Message(w.mw, "Archive illisible", err.Error())
			return nil
		case len(members) == 0:
			Message(w.mw, "Archive", "Aucun journal dans "+filepath.Base(path)+".")
			return nil
		case len(members) == 1:
			member = members[0]
		default:
			i, ok := ChooseItem(w.mw, "Contenu de l'archive", filepath.Base(path)+" contient plusieurs fichiers :", members)
			if !ok {
				return nil
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
		return nil
	}
	pane, err := w.addPane(src, followable, title, path, -1, true)
	if err != nil {
		Message(w.mw, "Ouverture impossible", err.Error())
		return nil
	}
	pane.path, pane.member = path, member
	return pane
}

// addPane shows a journal in a new tab at `at` (-1: at the end). In front
// unless `foreground` is false and a tab is already looked at.
func (w *window) addPane(src logcore.Follower, followable bool, title, location string, at int, foreground bool) (*logPane, error) {
	doc := logview.NewDoc(w.rules, src, followable)
	pane, err := newLogPane(w.stack, doc, title, location, w.font(), w.detailEnabled)
	if err != nil {
		doc.Close()
		return nil, err
	}
	pane.onZoom = w.zoom
	pane.onCopy = func(messageOnly bool) { w.reportCopy(pane.Copy(messageOnly)) }
	pane.onChange = w.refreshStatus
	front := w.current()
	w.strip.Insert(pane, at)
	if !foreground && front != nil {
		for i, p := range w.strip.Items {
			if p == front {
				w.strip.Active = i
			}
		}
	}
	w.applyFiltersTo(pane)
	doc.Start()
	w.tabChanged()
	return pane, nil
}

func (w *window) closeTab(i int) {
	pane, ok := w.strip.Remove(i)
	if !ok {
		return
	}
	pane.Close()
	delete(w.restored, pane)
	w.tabChanged()
}

// -- filters -------------------------------------------------------------------------------

// effective is the saved filters plus the criterion being typed.
func (w *window) effective() logcore.FilterSet {
	f := w.filters.Copy()
	if live := w.search.Current(); live.Pattern != "" {
		f.TextFilters = append(f.TextFilters, live)
	}
	return f
}

func (w *window) applyFiltersTo(p *logPane) {
	f := w.effective()
	if p.doc.SetFilters(f) == nil {
		p.SetPatterns(logcore.HighlightPatterns(&f))
	}
}

// applyFilters applies the effective filters to every tab.
func (w *window) applyFilters() {
	for _, p := range w.strip.Items {
		w.applyFiltersTo(p)
		p.Refresh()
	}
	w.search.SetCommonContext(w.filters.SearchContextLines)
	w.refreshStatus()
}

// sideChanged follows a change made in the side panel.
func (w *window) sideChanged() {
	w.markModified()
	w.applyFilters()
}

func (w *window) addCurrentFilter() {
	live := w.search.Current()
	if live.Pattern == "" {
		return
	}
	w.filters.TextFilters = append(w.filters.TextFilters, live)
	w.search.Clear()
	w.markModified()
	w.chips.Refresh(w.filters.TextFilters)
	w.applyFilters()
}

func (w *window) removeFilter(i int) {
	if i < 0 || i >= len(w.filters.TextFilters) {
		return
	}
	w.filters.TextFilters = append(w.filters.TextFilters[:i], w.filters.TextFilters[i+1:]...)
	w.markModified()
	w.chips.Refresh(w.filters.TextFilters)
	w.applyFilters()
}

func (w *window) resetFilters() {
	w.filters = logcore.NewFilterSet()
	w.search.Clear()
	w.markModified()
	w.side.Apply()
	w.chips.Refresh(w.filters.TextFilters)
	w.applyFilters()
}

// setFiltersPanel hides the side panel or shows it again. Hidden, it is not
// disabled: its filters still apply, and the status bar says how many lines they hide.
func (w *window) setFiltersPanel(on bool) {
	w.actFilters.SetChecked(on)
	w.side.root.SetVisible(on)
	if on {
		w.filtersToggle.SetBack(dark.Highlight)
	} else {
		w.filtersToggle.SetBack(dark.Button)
	}
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
		w.side.Refresh(current.doc.Counts())
		w.panelAt = time.Now()
	}
	w.tabs.Refresh()
	w.refreshStatus()
}

func (w *window) tick(exit *int) {
	for _, p := range w.strip.Items {
		if !p.doc.Dirty() {
			continue
		}
		p.Refresh()
		if p != w.current() {
			continue
		}
		w.refreshStatus()
		// While a big journal is indexed, rebuilding the panel at every slice
		// costs more than the indexing: spaced, then once more at the end.
		if !p.doc.Status().Indexing || time.Since(w.panelAt) > panelRefreshEvery {
			w.side.Refresh(p.doc.Counts())
			w.panelAt = time.Now()
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

// focusInEdit tells that the keyboard is in a text field.
func focusInEdit() bool { return dark.ClassName(win.GetFocus()) == "Edit" }

// copy copies what is selected where the user is looking: text selected in a
// field or in the detail panel stays a text copy, as in the Python; otherwise the rows.
func (w *window) copy(messageOnly bool) {
	if !messageOnly && focusInEdit() {
		win.SendMessage(win.GetFocus(), win.WM_COPY, 0, 0)
		if p := w.current(); p != nil && win.GetFocus() == p.detail.Handle() {
			w.showMessage("Sélection copiée.", 2*time.Second)
		}
		return
	}
	if p := w.current(); p != nil {
		w.reportCopy(p.Copy(messageOnly))
	}
}

func (w *window) reportCopy(count int) {
	w.showMessage(logview.CopyReport(count), 2*time.Second)
}

func (w *window) selectAll() {
	if focusInEdit() {
		win.SendMessage(win.GetFocus(), win.EM_SETSEL, 0, ^uintptr(0))
		return
	}
	p := w.current()
	if p == nil {
		return
	}
	for _, lv := range p.listViews {
		item := win.LVITEM{StateMask: win.LVIS_SELECTED, State: win.LVIS_SELECTED}
		win.SendMessage(lv, win.LVM_SETITEMSTATE, ^uintptr(0), uintptr(unsafe.Pointer(&item))) // -1: every item
	}
}

// toggleFollow is the F key. Typed in a text field, F is a letter: the menu's
// shortcut would steal it, so it is given back to the field.
func (w *window) toggleFollow() {
	if focusInEdit() {
		w.actFollow.SetChecked(!w.actFollow.Checked()) // undo the toggle the shortcut made
		win.SendMessage(win.GetFocus(), win.WM_CHAR, 'f', 0)
		return
	}
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
		w.smokeDone = true
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
				w.smokeDone = true
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
