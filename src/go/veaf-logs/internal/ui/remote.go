//go:build windows

package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/apilog"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

// Remote journals: the File menu's entry (M3), the host key question (O3) and
// the session's remote tabs (X2–X4); over SSH, or through a server's RestAPI
// (FEAT-VEAF-LOGS-REST-API).
//
// The Python connects on the window's thread, frozen up to the connection's
// delay per server; here the connection runs on a goroutine and hands the
// source back to the window, which only then makes the tab.

// remoteSource is a remote journal that can be opened: an SSH or an API one.
type remoteSource interface {
	logcore.Follower
	Open() error
}

// remoteLog is one choice of the remote dialog: an SSH instance, or a log of an API.
type remoteLog struct {
	server sshlog.Server
	log    string
}

// openRemoteDialog proposes the configuration's `server › instance` (`open_remote_dialog`).
// An API server without `logs:` is asked what it has, in the background.
func (w *window) openRemoteDialog() {
	servers, err := sshlog.LoadServers()
	if err != nil {
		Message(w.mw, "Configuration invalide", sshlog.FindConfig()+"\n"+err.Error())
		return
	}
	if len(servers) == 0 {
		Message(w.mw, "Aucun serveur configuré", "Déclare un bloc `servers:` dans "+sshlog.DefaultConfigPath()+".\nVoir la page « Journaux » de la documentation.")
		return
	}
	w.showMessage("Recherche des journaux distants…", 2*time.Minute) // cleared when the answers arrive
	go func() {
		choices, problems := remoteChoices(servers)
		w.synchronize(func() {
			w.showMessage("", 0)
			if len(choices) == 0 {
				Message(w.mw, "Aucun journal distant", strings.Join(problems, "\n"))
				return
			}
			if len(problems) > 0 {
				w.showMessage(strings.Join(problems, "   —   "), 15*time.Second)
			}
			labels := make([]string, len(choices))
			for i, c := range choices {
				labels[i] = c.server.Name + " › " + c.log
			}
			i, ok := ChooseItem(w.mw, "Journal distant", "Serveur et instance :", labels)
			if !ok {
				return
			}
			w.openRemote(choices[i].server, choices[i].log, "", func() int { return -1 }, true, func(_ *logPane, err error) {
				if err != nil {
					Message(w.mw, "Ouverture impossible", logview.ProblemText(err))
				}
			})
		})
	}()
}

// remoteChoices lists the logs of every server, asking the APIs that have no
// `logs:`; what could not be asked is said in `problems`. It touches the network.
func remoteChoices(servers []sshlog.Server) (choices []remoteLog, problems []string) {
	for _, s := range servers {
		if s.API == nil {
			for _, instance := range s.Instances() {
				choices = append(choices, remoteLog{s, instance})
			}
			continue
		}
		var client *apilog.Client
		var err error
		if s.API.Logs == nil {
			client, err = apilog.Open(s.API)
		}
		var logs []apilog.Log
		if err == nil {
			logs, err = apilog.Discover(s, client)
		}
		if err != nil {
			problems = append(problems, s.Name+" : "+logview.ProblemText(err))
			continue
		}
		for _, l := range logs {
			choices = append(choices, remoteLog{s, l.Name})
		}
	}
	return choices, problems
}

// newRemoteSource makes the source of a server's log, or of one of its older
// files (`file`, API only), and says where it is for the messages.
func (w *window) newRemoteSource(s sshlog.Server, log, file string) (remoteSource, string, error) {
	if s.API == nil {
		path := s.Logs[log]
		location := s.User + "@" + s.Host + ":" + path
		src, err := logcore.NewRemoteSource(path, location, sshlog.Connector(s, sshlog.Options{Ask: w.askHostKey}))
		return src, location, err
	}
	target, ok := s.APITarget(log)
	if !ok {
		return nil, "", fmt.Errorf("%s n'est pas dans les `logs:` de %s", log, s.Name)
	}
	client, err := apilog.Open(s.API)
	if err != nil {
		return nil, "", err
	}
	location := s.API.URL + " › " + log
	if file != "" {
		location += " › " + file
	}
	src, err := logcore.NewAPISource(client.Log(target), logcore.APISourceOptions{File: file, Bot: target.Instance == ""})
	return src, location, err
}

// openRemote connects to a server's log in the background, then shows it in a
// tab placed at `at()`, computed when the journal arrives: the tabs may have
// changed meanwhile. `file` is an older file of an API log, opened read-only
// and not kept in the session. `done` runs on the window's thread, unless the
// window closed first.
func (w *window) openRemote(s sshlog.Server, log, file string, at func() int, foreground bool, done func(*logPane, error)) {
	src, location, err := w.newRemoteSource(s, log, file)
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
			title, remote := logview.RemoteTab(s.Name, log)
			if file != "" {
				title, remote = title+" › "+file, ""
			}
			pane, err := w.addPane(src, file == "", title, location, at(), foreground)
			if err != nil {
				done(nil, err)
				return
			}
			pane.remote = remote
			if s.API == nil {
				pane.path = s.Logs[log]
			} else {
				pane.api = &remoteLog{s, log}
			}
			done(pane, nil)
		})
	}()
}

// openOlderDialog lists the files of the current API tab's log and opens the
// chosen one read-only, from its start.
func (w *window) openOlderDialog() {
	p := w.current()
	if p == nil || p.api == nil {
		Message(w.mw, "Ancien journal", "Seul un journal ouvert par l'API d'un serveur (bloc `api:`) propose ses anciens fichiers.")
		return
	}
	s, log := p.api.server, p.api.log
	target, _ := s.APITarget(log)
	w.showMessage("Liste des fichiers de "+s.Name+" › "+log+"…", 10*time.Second)
	go func() {
		client, err := apilog.Open(s.API)
		var files []apilog.File
		if err == nil {
			files, err = client.Files(target)
		}
		w.synchronize(func() {
			w.showMessage("", 0)
			if err != nil {
				Message(w.mw, "Liste impossible", logview.ProblemText(err))
				return
			}
			labels := make([]string, len(files))
			for i, f := range files {
				labels[i] = fmt.Sprintf("%s   —   %s   —   %s UTC", f.Name, sizeText(f.Size), f.Modified.UTC().Format("2006-01-02 15:04"))
				if f.Live {
					labels[i] += "   (en cours)"
				}
			}
			i, ok := ChooseItem(w.mw, "Ancien journal", s.Name+" › "+log+" :", labels)
			if !ok {
				return
			}
			w.openRemote(s, log, files[i].Name, func() int { return -1 }, true, func(_ *logPane, err error) {
				if err != nil {
					Message(w.mw, "Ouverture impossible", logview.ProblemText(err))
				}
			})
		})
	}()
}

func sizeText(n int64) string {
	switch {
	case n >= 1<<20:
		return fmt.Sprintf("%.1f Mo", float64(n)/(1<<20))
	case n >= 1<<10:
		return fmt.Sprintf("%d ko", n>>10)
	}
	return fmt.Sprintf("%d o", n)
}

// synchronize runs f on the window's thread, unless the window is gone.
func (w *window) synchronize(f func()) {
	select {
	case <-w.done:
		return
	default:
	}
	w.mw.Synchronize(func() {
		w.connMu.Lock()
		closed := w.closed
		w.connMu.Unlock()
		if !closed {
			f()
		}
	})
}

// handOver puts an opened source where the window will claim it; when the
// window is already closing, the source is released here and false returned.
func (w *window) handOver(src remoteSource) bool {
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
func (w *window) claim(src remoteSource) bool {
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
	w.unclaimed = map[remoteSource]bool{}
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
	w.openRemote(server, instance, "", at, false, func(p *logPane, err error) {
		if err != nil {
			settle(false, w.restore.Failed(remote, err))
			return
		}
		w.restored[p] = true
		settle(true, "")
	})
}
