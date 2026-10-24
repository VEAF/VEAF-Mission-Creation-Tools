//go:build windows

package ui

import (
	"os"
	"syscall"
	"time"

	"golang.org/x/sys/windows"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
)

// The Règles menu (M19, M20). The catalogue is embedded in the executable; the
// shipped Python one reads its copy unpacked in a temporary folder, which its
// menu opens and F5 reloads, and which is gone when it exits. The Go viewer
// does the same with a temporary copy written the first time it is opened.

// reloadRules reads the catalogue again and indexes every open journal with it
// (`reload_rules`); an invalid catalogue changes nothing.
func (w *window) reloadRules() {
	data := logcore.EmbeddedRules()
	if w.rulesFile != "" {
		var err error
		if data, err = os.ReadFile(w.rulesFile); err != nil {
			Message(w.mw, "Catalogue invalide", err.Error())
			return
		}
	}
	rules, err := logcore.ParseRules(data)
	if err != nil {
		Message(w.mw, "Catalogue invalide", err.Error())
		return
	}
	w.rules = rules
	w.side.rules = rules
	profile := w.currentProfile()
	w.profiles = logview.NewProfileStore(rules, "")
	for _, p := range w.strip.Items {
		p.doc.Reclassify(rules)
	}
	w.reloadProfileBox(profile)
	if p := w.current(); p != nil {
		w.side.Refresh(p.doc.Counts())
	}
	w.applyFilters()
	w.showMessage("Catalogue rechargé.", 4*time.Second)
}

// openRulesFile opens the catalogue with the application Windows associates with .json.
func (w *window) openRulesFile() {
	if w.rulesFile == "" {
		f, err := os.CreateTemp("", "veaf-logs-rules-*.json")
		if err != nil {
			Message(w.mw, "Ouverture impossible", err.Error())
			return
		}
		_, err = f.Write(logcore.EmbeddedRules())
		if cerr := f.Close(); err == nil {
			err = cerr
		}
		if err != nil {
			os.Remove(f.Name())
			Message(w.mw, "Ouverture impossible", err.Error())
			return
		}
		w.rulesFile = f.Name()
	}
	verb, _ := syscall.UTF16PtrFromString("open")
	file, _ := syscall.UTF16PtrFromString(w.rulesFile)
	if err := windows.ShellExecute(windows.Handle(w.mw.Handle()), verb, file, nil, nil, windows.SW_SHOWNORMAL); err != nil {
		Message(w.mw, "Ouverture impossible", w.rulesFile+"\n"+err.Error())
	}
}
