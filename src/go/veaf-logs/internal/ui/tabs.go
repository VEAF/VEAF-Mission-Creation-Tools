//go:build windows

package ui

import (
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/apilog"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

// The tabs' list, their right-click menu and their aliases (FEAT-GO-VEAF-LOGS-TABS).
// An alias lives in ~/veafmct.yaml: renaming a tab here writes it there.

// aliasTarget is where a tab's alias lives: a server's log, or a local file. Empty: no alias.
type aliasTarget struct {
	server, log string
	local       string
}

func (a aliasTarget) ok() bool { return a.local != "" || a.server != "" }

// localAliasKey names a local file in `log_aliases:`: its path, and an archive's member after it.
func localAliasKey(path, member string) string {
	if member != "" {
		return path + "|" + member
	}
	return path
}

// applyAlias titles a local tab with its alias from the configuration, if any.
func (w *window) applyAlias(p *logPane) {
	aliases, err := sshlog.LoadLocalAliases()
	if err == nil && aliases[p.alias.local] != "" {
		p.title = aliases[p.alias.local]
		w.tabs.Refresh()
	}
}

// chooseTab lists the tabs and makes the chosen one current.
func (w *window) chooseTab() {
	titles := make([]string, len(w.strip.Items))
	for i, p := range w.strip.Items {
		titles[i] = p.title
	}
	if i, ok := popupMenu(w.mw.Handle(), titles, w.strip.Active); ok && i != w.strip.Active {
		w.strip.Active = i
		w.tabChanged()
	}
}

// tabMenu is a tab's right-click menu.
func (w *window) tabMenu(i int) {
	p := w.strip.Items[i]
	items := []string{"Fermer l'onglet"}
	if p.alias.ok() {
		items = append([]string{"Renommer l'onglet…"}, items...)
	}
	choice, ok := popupMenu(w.mw.Handle(), items, -1)
	switch {
	case !ok:
	case items[choice] == "Fermer l'onglet":
		w.closeTab(i)
	default:
		w.renameTab(p)
	}
}

// renameTab asks a tab's new name and writes it as its alias; empty goes back to its name.
func (w *window) renameTab(p *logPane) {
	current := p.title
	if current == p.name {
		current = ""
	}
	alias, ok := Prompt(w.mw, "Renommer l'onglet", "Nom de l'onglet (vide : "+p.name+") :", current)
	if !ok {
		return
	}
	config := sshlog.FindConfig()
	if config == "" {
		config = sshlog.DefaultConfigPath()
	}
	var err error
	if p.alias.local != "" {
		err = sshlog.SetLocalAlias(config, p.alias.local, alias)
	} else {
		err = sshlog.SetAlias(config, p.alias.server, p.alias.log, alias)
	}
	if err != nil {
		Message(w.mw, "Renommage impossible", err.Error())
		return
	}
	// Every tab of that log takes it: the same journal may be open twice.
	for _, q := range w.strip.Items {
		if q.alias == p.alias {
			q.title = q.name
			if alias != "" {
				q.title = alias
			}
		}
	}
	w.tabs.Refresh()
	w.showMessage("Alias écrit dans "+config, 5*time.Second)
}

// rememberNames keeps the logs an API server listed, for their shortened titles.
func (w *window) rememberNames(s sshlog.Server, logs []apilog.Log) {
	names := make([]string, 0, len(logs))
	for _, l := range logs {
		if l.Target.Instance != "" { // the bot log is not one of the servers
			names = append(names, l.Name)
		}
	}
	w.connMu.Lock()
	w.apiNames[s.Name] = names
	w.connMu.Unlock()
}

// shortName is a discovered log's title without the words all of its API's
// servers share, "" when there is nothing to shorten. It may ask the API for
// its servers once (a tab restored without the menu): never on the window's thread.
func (w *window) shortName(s sshlog.Server, log string) string {
	if s.API == nil || s.API.Logs != nil {
		return ""
	}
	w.connMu.Lock()
	names, known := w.apiNames[s.Name]
	w.connMu.Unlock()
	if !known {
		if c, err := apilog.Open(s.API); err == nil {
			if logs, err := apilog.Discover(s, c); err == nil {
				w.rememberNames(s, logs)
				w.connMu.Lock()
				names = w.apiNames[s.Name]
				w.connMu.Unlock()
			}
		}
	}
	short := logview.ShortNames(names)
	for i, n := range names {
		if n == log && short[i] != n {
			return short[i]
		}
	}
	return ""
}
