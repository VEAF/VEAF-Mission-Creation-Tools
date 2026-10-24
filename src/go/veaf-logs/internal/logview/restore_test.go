package logview

import (
	"errors"
	"fmt"
	"reflect"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

func remoteFile(remote string) OpenFile {
	path := "C:/" + remote + "/dcs.log"
	return OpenFile{Path: path, Remote: &remote}
}

func names(files []OpenFile) []string {
	var out []string
	for _, f := range files {
		if f.Remote != nil {
			out = append(out, *f.Remote)
		} else {
			out = append(out, f.Path)
		}
	}
	return out
}

// Session [r1, a, r2, b]: the local tabs open first, each remote one then goes
// back between them, in the session's order.
func TestRemoteTabsGoBackToTheirPlace(t *testing.T) {
	r := NewRestore()
	r.Defer(0, remoteFile("veaf/r1"))
	r.Opened(1)
	r.Defer(2, remoteFile("veaf/r2"))
	r.Opened(3)
	tabs := []string{"a", "b"}

	for r.Pending() {
		p, _ := r.Next()
		at := r.Slot(len(tabs))
		tabs = append(tabs[:at], append([]string{*p.File.Remote}, tabs[at:]...)...)
		r.Done(true)
	}
	if want := []string{"veaf/r1", "a", "veaf/r2", "b"}; !reflect.DeepEqual(tabs, want) {
		t.Fatalf("tabs %v, want %v", tabs, want)
	}
}

// A remote tab that does not come back leaves no hole: the next one still lands right.
func TestAFailedRemoteTabShiftsNothing(t *testing.T) {
	r := NewRestore()
	r.Defer(0, remoteFile("veaf/r1"))
	r.Defer(1, remoteFile("veaf/r2"))
	r.Opened(2)
	r.Done(false) // r1 failed
	if at := r.Slot(1); at != 0 {
		t.Fatalf("r2 goes at %d, want 0 (before the local tab)", at)
	}
	r.Done(true)
	if r.Pending() {
		t.Fatal("nothing should remain")
	}
}

// Closing before the remote tabs came back keeps them at their place in the
// saved session, and the tab looked at stays the active one (Python's
// test_fermer_pendant_la_restauration_garde_les_distants).
func TestMergeKeepsWhatWasNotReopened(t *testing.T) {
	r := NewRestore()
	r.Defer(0, remoteFile("veaf/r1"))
	r.Opened(1)
	files, active := r.Merge([]OpenFile{{Path: "a.log"}}, 0)
	if got := names(files); !reflect.DeepEqual(got, []string{"veaf/r1", "a.log"}) || active != 1 {
		t.Fatalf("files %v active %d, want [veaf/r1 a.log] active 1", got, active)
	}

	// With no tab at all, the active index is not shifted.
	r = NewRestore()
	r.Defer(0, remoteFile("veaf/r1"))
	r.Defer(1, remoteFile("veaf/r2"))
	files, active = r.Merge(nil, 0)
	if got := names(files); !reflect.DeepEqual(got, []string{"veaf/r1", "veaf/r2"}) || active != 0 {
		t.Fatalf("files %v active %d", got, active)
	}

	// Abandoned: the session holds only what is open.
	r.Abandon()
	if files, _ := r.Merge([]OpenFile{{Path: "a.log"}}, 0); len(files) != 1 {
		t.Fatalf("abandoned: %v", names(files))
	}
}

// The tab being connected is still in the session if the window closes meanwhile.
func TestTheTabBeingConnectedIsSaved(t *testing.T) {
	r := NewRestore()
	r.Defer(0, remoteFile("veaf/r1"))
	if _, ok := r.Next(); !ok {
		t.Fatal("no next")
	}
	if files, _ := r.Merge(nil, 0); len(files) != 1 {
		t.Fatalf("the tab being connected was lost: %v", names(files))
	}
}

func TestResolveAndFailureMessages(t *testing.T) {
	servers := []sshlog.Server{{Name: "veaf", Logs: map[string]string{"a": "C:/a/dcs.log", "b": "C:/b/dcs.log"}}}
	r := NewRestore()
	s, instance, msg, ok := r.Resolve("veaf/a", servers)
	if !ok || s.Name != "veaf" || instance != "a" || msg != "" {
		t.Fatalf("veaf/a: %v %q %q %v", s.Name, instance, msg, ok)
	}
	if _, _, msg, ok := r.Resolve("veaf/gone", servers); ok || msg != "veaf/gone n'est plus dans la configuration, onglet non rouvert" {
		t.Fatalf("gone: %q", msg)
	}
	if _, _, msg, ok := r.Resolve("other/a", servers); ok || msg == "" {
		t.Fatalf("unknown server: %q", msg)
	}

	// A missing journal is not the server's fault: its other instances are tried.
	missing := fmt.Errorf("C:/a/dcs.log: %w", logcore.ErrRemoteFileMissing)
	if msg := r.Failed("veaf/a", missing); msg != "veaf/a non rouvert : "+missing.Error() {
		t.Fatalf("missing: %q", msg)
	}
	if _, _, _, ok := r.Resolve("veaf/b", servers); !ok {
		t.Fatal("a missing journal must not mark the server unreachable")
	}
	// A server that did not answer is not tried again for its other instances.
	r.Failed("veaf/a", errors.New("connection refused"))
	if _, _, msg, ok := r.Resolve("veaf/b", servers); ok || msg != "veaf/b : serveur injoignable, onglet non rouvert" {
		t.Fatalf("unreachable: %q", msg)
	}
}
