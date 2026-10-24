package logview

import (
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

// Restore keeps a session's order while its remote tabs are reopened after the
// window shows, one at a time (`_restore`, `_reopen_next_remote`, `_capture` of
// the Python). A remote tab costs an SSH connection and a download: reopened
// before the window, three of them delayed it by 8 s (FIX-LOGS-EXE-STARTUP-AND-VERSION).
type Restore struct {
	// positions are the session positions of the tabs the restore opened, in tab order.
	positions []int
	// pending are the remote tabs not reopened yet, in session order. The one
	// being connected stays here until Done: closing the window meanwhile keeps
	// it in the saved session.
	pending     []PendingTab
	unreachable map[string]bool
}

// PendingTab is a remote tab of the session waiting to be reopened.
type PendingTab struct {
	Position int
	File     OpenFile
}

// NewRestore is a restore with nothing opened yet.
func NewRestore() *Restore { return &Restore{unreachable: map[string]bool{}} }

// Opened records a tab the restore opened after the others (a local one).
func (r *Restore) Opened(position int) { r.positions = append(r.positions, position) }

// Defer puts a remote tab of the session aside, to reopen once the window shows.
func (r *Restore) Defer(position int, f OpenFile) {
	r.pending = append(r.pending, PendingTab{Position: position, File: f})
}

// Next is the remote tab to reopen now; it stays pending until Done.
func (r *Restore) Next() (PendingTab, bool) {
	if len(r.pending) == 0 {
		return PendingTab{}, false
	}
	return r.pending[0], true
}

// Slot is where the next remote tab goes among the `tabs` open: after the
// restored tabs that came before it in the session.
func (r *Restore) Slot(tabs int) int {
	p, ok := r.Next()
	if !ok {
		return tabs
	}
	return min(r.after(p.Position), tabs)
}

// after counts the restored tabs placed before a session position (`bisect.bisect`).
func (r *Restore) after(position int) int {
	return sort.Search(len(r.positions), func(i int) bool { return r.positions[i] > position })
}

// Done ends the attempt on the next remote tab; `reopened` records its place.
func (r *Restore) Done(reopened bool) {
	p, ok := r.Next()
	if !ok {
		return
	}
	r.pending = r.pending[1:]
	if reopened {
		at := r.after(p.Position)
		r.positions = append(r.positions, 0)
		copy(r.positions[at+1:], r.positions[at:])
		r.positions[at] = p.Position
	}
}

// Pending tells that remote tabs remain to be reopened.
func (r *Restore) Pending() bool { return len(r.pending) > 0 }

// Abandon gives up the remote tabs not reopened yet: nothing reopens them any more.
func (r *Restore) Abandon() { r.pending = nil }

// Merge puts the remote tabs not reopened yet back at their place among the
// open tabs `files`, and shifts the active tab accordingly: saved now, the
// session is the one that was restored plus what the user changed.
func (r *Restore) Merge(files []OpenFile, active int) ([]OpenFile, int) {
	tabs := len(files)
	out := append([]OpenFile(nil), files...)
	for inserted, p := range r.pending {
		at := min(r.after(p.Position)+inserted, len(out))
		out = append(out, OpenFile{})
		copy(out[at+1:], out[at:])
		out[at] = p.File
		if tabs > 0 && at <= active {
			active++
		}
	}
	return out, active
}

// Resolve finds the server and instance of a session's `server/instance`; when
// it is not reopened, the status bar message says why. Messages, not dialog
// boxes: offline, six remote tabs would make six boxes.
func (r *Restore) Resolve(remote string, servers []sshlog.Server) (server sshlog.Server, instance, message string, ok bool) {
	name, instance, _ := strings.Cut(remote, "/")
	if r.unreachable[name] {
		return sshlog.Server{}, "", remote + " : serveur injoignable, onglet non rouvert", false
	}
	for _, s := range servers {
		if _, found := s.Logs[instance]; found && s.Name == name {
			return s, instance, "", true
		}
	}
	return sshlog.Server{}, "", remote + " n'est plus dans la configuration, onglet non rouvert", false
}

// Failed is the message of a remote tab that could not be reopened. A server
// that did not answer is not tried again for its other instances: each attempt
// costs the connection's delay. A missing journal is not the server's fault.
func (r *Restore) Failed(remote string, err error) string {
	if !errors.Is(err, logcore.ErrRemoteFileMissing) {
		name, _, _ := strings.Cut(remote, "/")
		r.unreachable[name] = true
	}
	return fmt.Sprintf("%s non rouvert : %v", remote, err)
}
