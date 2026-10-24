//go:build windows

package ui

import (
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

// Remote journals: the File menu's entry (M3), the host key question (O3) and
// the session's remote tabs (X2–X4).
//
// The Python connects on the window's thread, frozen up to the connection's
// delay per server; here the connection runs on a goroutine and hands the
// source back to the window, which only then makes the tab.

// openRemoteDialog proposes the configuration's `server › instance` (`open_remote_dialog`).
func (w *window) openRemoteDialog() {
	servers, err := sshlog.LoadServers()
	if err != nil {
		Message(w.mw, "Configuration invalide", sshlog.FindConfig()+"\n"+err.Error())
		return
	}
	var labels []string
	var choices []struct {
		server   sshlog.Server
		instance string
	}
	for _, s := range servers {
		for _, instance := range s.Instances() {
			labels = append(labels, s.Name+" › "+instance)
			choices = append(choices, struct {
				server   sshlog.Server
				instance string
			}{s, instance})
		}
	}
	if len(choices) == 0 {
		Message(w.mw, "Aucun serveur configuré", "Déclare un bloc `servers:` dans "+sshlog.DefaultConfigPath()+".\nVoir la page « Journaux » de la documentation.")
		return
	}
	i, ok := ChooseItem(w.mw, "Journal distant", "Serveur et instance :", labels)
	if !ok {
		return
	}
	c := choices[i]
	w.openRemote(c.server, c.instance, func() int { return -1 }, true, func(_ *logPane, err error) {
		if err != nil {
			Message(w.mw, "Ouverture impossible", err.Error())
		}
	})
}

// openRemote connects to a server's instance in the background, then shows it
// in a tab placed at `at()`, computed when the journal arrives: the tabs may
// have changed meanwhile. `done` runs on the window's thread, unless the
// window closed first.
func (w *window) openRemote(s sshlog.Server, instance string, at func() int, foreground bool, done func(*logPane, error)) {
	path := s.Logs[instance]
	location := s.User + "@" + s.Host + ":" + path
	src, err := logcore.NewRemoteSource(path, location, sshlog.Connector(s, sshlog.Options{Ask: w.askHostKey}))
	if err != nil {
		done(nil, err)
		return
	}
	if foreground {
		// Not while restoring: it would wipe the message of the tab that just failed.
		w.showMessage("Connexion à "+location+"…", 10*time.Second)
	}
	go func() {
		err := src.Open()
		if !w.handOver(src) {
			return
		}
		w.mw.Synchronize(func() {
			if !w.claim(src) {
				return // the window closed: closeConnections released it
			}
			if err != nil {
				src.Close()
				done(nil, err)
				return
			}
			pane, err := w.addPane(src, true, s.Name+":"+instance, location, at(), foreground)
			if err != nil {
				done(nil, err)
				return
			}
			pane.path, pane.remote = path, s.Name+"/"+instance
			done(pane, nil)
		})
	}()
}

// handOver puts an opened source where the window will claim it; when the
// window is already closing, the source is released here and false returned.
func (w *window) handOver(src *logcore.RemoteSource) bool {
	w.connMu.Lock()
	defer w.connMu.Unlock()
	if w.closed {
		src.Close()
		return false
	}
	w.unclaimed[src] = true
	return true
}

// claim takes a handed over source for a tab; false when closeConnections already released it.
func (w *window) claim(src *logcore.RemoteSource) bool {
	w.connMu.Lock()
	defer w.connMu.Unlock()
	ok := w.unclaimed[src]
	delete(w.unclaimed, src)
	return ok
}

// closeConnections releases the sources opened but not shown yet: the window
// is closing, and nothing else would close their connection and mirror file.
func (w *window) closeConnections() {
	w.connMu.Lock()
	defer w.connMu.Unlock()
	w.closed = true
	for src := range w.unclaimed {
		src.Close()
	}
	w.unclaimed = map[*logcore.RemoteSource]bool{}
}

// askHostKey asks, from a connection's goroutine, whether to trust a server
// absent from known_hosts (`_ask_host_key`). The window gone, the answer is no.
func (w *window) askHostKey(host, fingerprint string) bool {
	w.connMu.Lock()
	closed := w.closed
	w.connMu.Unlock()
	if closed {
		return false
	}
	answer := make(chan bool, 1)
	w.mw.Synchronize(func() {
		answer <- Confirm(w.mw, "Hôte inconnu", "La clé de "+host+" n'est pas dans known_hosts.\n\n"+fingerprint+"\n\nL'accepter et la mémoriser ?")
	})
	select {
	case ok := <-answer:
		return ok
	case <-w.done:
		return false
	}
}

// reopenNextRemote reopens the session's next remote tab, then the one after
// it once this one is settled, in the session's order (`_reopen_next_remote`).
// A failure goes to the status bar, never a dialog box.
func (w *window) reopenNextRemote() {
	next, ok := w.restore.Next()
	if !ok {
		w.finishRestore()
		return
	}
	remote := *next.File.Remote
	settle := func(reopened bool, message string) {
		if message != "" {
			w.showMessage(message, 10*time.Second)
		}
		w.restore.Done(reopened)
		w.reopenNextRemote()
	}
	servers, err := sshlog.LoadServers()
	if err != nil {
		settle(false, "") // an invalid configuration is said when it is opened from the menu
		return
	}
	server, instance, message, ok := w.restore.Resolve(remote, servers)
	if !ok {
		settle(false, message)
		return
	}
	at := func() int { return w.restore.Slot(len(w.strip.Items)) }
	w.openRemote(server, instance, at, false, func(p *logPane, err error) {
		if err != nil {
			settle(false, w.restore.Failed(remote, err))
			return
		}
		w.restored[p] = true
		settle(true, "")
	})
}
