//go:build windows

package ui

import (
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/analysis"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// *Analyse › Expliquer ce qui est affiché…* (B1–B4): the catalogue layer is
// computed and shown at once; nothing leaves the machine until « Analyser en
// ligne » is pressed, and then only the redacted, bounded excerpt.
// « Préparer un rapport » sends nothing: it fills the clipboard.

// explain opens the analysis of what the current tab shows.
func (w *window) explain() {
	p := w.current()
	if p == nil {
		w.showMessage("Aucun journal ouvert à analyser.", 3*time.Second)
		return
	}
	var a analysis.Analysis
	var err error
	p.doc.Read(func(store *logcore.Store, filters logcore.FilterSet, visible []int) {
		a, err = analysis.Analyse(analysis.MachineRedactor(), store, p.doc.Rules, &filters, visible, analysis.DefaultMaxChars)
	})
	if err != nil {
		Message(w.mw, "Analyse impossible", err.Error())
		return
	}
	w.analysisDialog(a)
}

// crlf is what a Win32 edit control needs to break a line.
func crlf(s string) string { return strings.ReplaceAll(s, "\n", "\r\n") }

func (w *window) analysisDialog(a analysis.Analysis) {
	var dlg *walk.Dialog
	var question *walk.LineEdit
	var online, report, closeButton *walk.PushButton
	var text *walk.TextEdit
	var status *walk.Label
	running, closed := false, false

	runOnline := func() {
		if running {
			return // one request at a time
		}
		running = true
		online.SetEnabled(false)
		status.SetText("Analyse en ligne en cours…")
		current, q := a, strings.TrimSpace(question.Text())
		go func() {
			answered := analysis.Online(current, analysis.DefaultEndpoint, q)
			dlg.Synchronize(func() {
				if closed {
					return
				}
				a = answered
				text.SetText(crlf(a.Text()))
				if a.ModelError != "" {
					status.SetText(a.ModelError)
				} else {
					status.SetText("Analyse en ligne reçue.")
				}
				online.SetEnabled(true)
				running = false
			})
		}()
	}
	copyReport := func() {
		// Collected here, not when the window opens: it reads the tool's log
		// and probes the DCS install, which nobody should pay for by opening it.
		now := time.Now()
		doctor := analysis.CollectDoctor(analysis.MachineRedactor(), now)
		block := analysis.BuildReport(analysis.MachineRedactor(), a, &doctor, analysis.DiscordMessageLimit, now)
		if err := walk.Clipboard().SetText(crlf(analysis.ToClipboard(block))); err != nil {
			status.SetText("Copie impossible : " + err.Error())
			return
		}
		status.SetText(fmt.Sprintf("Rapport copié (%d caractères). Colle-le dans /bug.", utf8.RuneCountInString(block)))
	}

	err := Dialog{
		AssignTo: &dlg, Title: "Analyse du journal", CancelButton: &closeButton,
		// walk opens a dialog at its minimum size: 1000×700 as the Python, relaxed once shown.
		MinSize:    Size{Width: 1000, Height: 700},
		Background: SolidColorBrush{Color: dark.Window},
		Layout:     VBox{Margins: Margins{Left: 12, Top: 12, Right: 12, Bottom: 12}},
		Children: []Widget{
			Composite{Layout: HBox{MarginsZero: true}, Background: SolidColorBrush{Color: dark.Window}, Children: []Widget{
				LineEdit{AssignTo: &question, CueBanner: "Question facultative pour l'analyse en ligne…", TextColor: dark.Text, StretchFactor: 1},
				PushButton{AssignTo: &online, Text: "Analyser en ligne", OnClicked: runOnline,
					ToolTipText: "Envoie l'extrait caviardé et les motifs du catalogue au service VEAF. Rien d'autre ne part."},
				PushButton{AssignTo: &report, Text: "Préparer un rapport", OnClicked: copyReport,
					ToolTipText: "Copie un bloc collable dans /bug : diagnostic, extrait, catalogue, analyse."},
			}},
			TextEdit{AssignTo: &text, ReadOnly: true, HScroll: true, VScroll: true, StretchFactor: 1,
				TextColor: dark.Text, Background: SolidColorBrush{Color: dark.Alternate}, Text: crlf(a.Text())},
			Label{AssignTo: &status, Text: " ", TextColor: dark.Text},
			Composite{Layout: HBox{MarginsZero: true}, Background: SolidColorBrush{Color: dark.Window}, Children: []Widget{
				HSpacer{},
				PushButton{AssignTo: &closeButton, Text: "Fermer", OnClicked: func() { dlg.Cancel() }},
			}},
		},
	}.Create(w.mw)
	if err != nil {
		Message(w.mw, "Analyse impossible", err.Error())
		return
	}
	text.SetFont(w.font())
	question.SetBackground(dark.WalkBrush(dark.Alternate))
	dark.Theme(text.Handle(), "DarkMode_Explorer")
	dark.NoEdge(text.Handle())
	darkenDialog(dlg)
	dlg.Activating().Once(func() { _ = dlg.SetMinMaxSize(walk.Size{Width: 600, Height: 400}, walk.Size{}) })
	dlg.Run()
	closed = true // an answer arriving now has nowhere to go
}
