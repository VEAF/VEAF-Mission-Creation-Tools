//go:build windows

package ui

import (
	"strings"
	"time"

	. "github.com/tailscale/walk/declarative"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// The profile bar (main_window.py, _build_profile_bar): the filters panel's
// button, the profile chooser, save and delete, and the zoom at mouse reach.

var profileSyncing bool // true while the window sets the chooser itself

func (w *window) profileBar() Composite {
	return Composite{
		Layout: HBox{Margins: Margins{Left: 6, Top: 4, Right: 6, Bottom: 2}}, Background: SolidColorBrush{Color: dark.Window},
		Children: []Widget{
			declarePainted(&w.filtersToggle, 90, 24),
			Label{Text: "Profil :", TextColor: dark.Text},
			ComboBox{AssignTo: &w.profileBox, MinSize: Size{Width: 250}, ToolTipText: "Jeu de filtres enregistré", OnCurrentIndexChanged: w.profileChosen},
			PushButton{Text: "Enregistrer…", ToolTipText: "Enregistrer les filtres courants sous un nom", OnClicked: w.saveProfile},
			PushButton{AssignTo: &w.profileDelete, Text: "Supprimer", OnClicked: w.deleteProfile},
			HSpacer{StretchFactor: 1000},
			declarePainted(&w.zoomOut, 32, 24),
			declarePainted(&w.zoomIn, 32, 24),
		},
	}
}

func (w *window) finishProfileBar() {
	dark.Theme(w.profileBox.Handle(), "DarkMode_CFD")
	dark.ListColors(w.profileBox.Handle())
	for _, h := range dark.Children(w.profileBox.Parent().Handle()) {
		if dark.ClassName(h) == "Button" {
			dark.Theme(h, "DarkMode_Explorer")
		}
	}
	w.filtersToggle.widget.SetToolTipText("Masquer ou afficher les filtres de gauche  (Ctrl+B)")
	w.zoomOut.widget.SetToolTipText("Réduire la police  (Ctrl+-, ou Ctrl+molette)")
	w.zoomIn.widget.SetToolTipText("Agrandir la police  (Ctrl++, ou Ctrl+molette)")
	selected := w.session.Profile
	if selected == "" {
		selected = logview.DefaultProfile
	}
	w.reloadProfileBox(selected)
}

// reloadProfileBox lists the unnamed current filters first, then the
// profiles, and selects one without loading it.
func (w *window) reloadProfileBox(selected string) {
	profileSyncing = true
	defer func() { profileSyncing = false }()
	w.profileChoices = append([]string{logview.DefaultProfile}, w.profiles.Names()...)
	w.profileBox.SetModel(w.profileChoices)
	index := 0
	for i, name := range w.profileChoices {
		if name == selected {
			index = i
		}
	}
	w.profileBox.SetCurrentIndex(index)
	w.updateProfileButtons()
}

func (w *window) currentProfile() string {
	i := w.profileBox.CurrentIndex()
	if i < 0 || i >= len(w.profileChoices) {
		return logview.DefaultProfile
	}
	return w.profileChoices[i]
}

func (w *window) updateProfileButtons() {
	name := w.currentProfile()
	w.profileDelete.SetEnabled(name != logview.DefaultProfile && !w.profiles.IsBuiltin(name))
}

func (w *window) profileChosen() {
	if profileSyncing {
		return
	}
	name := w.currentProfile()
	w.updateProfileButtons()
	if name == logview.DefaultProfile {
		return
	}
	f, ok := w.profiles.Get(name)
	if !ok {
		return
	}
	w.filters = f
	w.search.Clear()
	w.side.Apply()
	w.chips.Refresh(w.filters.TextFilters)
	w.applyFilters()
	w.showMessage("Profil « "+name+" » chargé.", 3*time.Second)
}

// markModified: the filters no longer match the profile shown, so the
// chooser goes back to the unnamed entry rather than suggest the saved
// profile changed.
func (w *window) markModified() {
	if w.currentProfile() == logview.DefaultProfile {
		return
	}
	profileSyncing = true
	w.profileBox.SetCurrentIndex(0)
	profileSyncing = false
	w.updateProfileButtons()
}

func (w *window) saveProfile() {
	current := w.currentProfile()
	initial := current
	if current == logview.DefaultProfile || w.profiles.IsBuiltin(current) {
		initial = ""
	}
	name, ok := Prompt(w.mw, "Enregistrer le profil", "Nom :", initial)
	if !ok {
		return
	}
	if err := w.profiles.Save(name, w.filters); err != nil {
		Message(w.mw, "Profil non enregistré", err.Error())
		return
	}
	name = strings.TrimSpace(name)
	w.reloadProfileBox(name)
	w.showMessage("Profil « "+name+" » enregistré.", 3*time.Second)
}

func (w *window) deleteProfile() {
	name := w.currentProfile()
	if name == logview.DefaultProfile || w.profiles.IsBuiltin(name) {
		return
	}
	if !Confirm(w.mw, "Supprimer le profil", "Supprimer définitivement « "+name+" » ?") {
		return
	}
	if err := w.profiles.Delete(name); err != nil {
		Message(w.mw, "Profil conservé", err.Error())
		return
	}
	w.reloadProfileBox(logview.DefaultProfile)
}
