package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

const (
	lineA = "2026-08-31 11:50:40.872 ERROR   APP (Main): alpha\n"
	lineB = "2026-08-31 11:50:41.000 INFO    APP (Main): beta\n"
	lineC = "2026-08-31 11:50:42.000 INFO    APP (Main): gamma\n"
)

func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timeout waiting for %s", what)
}

// The poll loop is the wiring between the file and the window: it must pick up
// appended lines, extend an active search, and start over after a rotation.
func TestPollFollowsAppendsAndRotation(t *testing.T) {
	path := filepath.Join(t.TempDir(), "dcs.log")
	if err := os.WriteFile(path, []byte(lineA), 0o644); err != nil {
		t.Fatal(err)
	}
	v, err := newViewer(path)
	if err != nil {
		t.Fatal(err)
	}
	go v.poll()
	count := func() int { v.mu.Lock(); defer v.mu.Unlock(); return v.store.Len() }

	waitFor(t, "first entry", func() bool { return count() == 1 })

	// An active search: only the new matching lines must join the result.
	v.mu.Lock()
	v.lastQ = "gamma"
	v.mu.Unlock()
	v.startSearch("gamma")
	waitFor(t, "search done", func() bool { v.mu.Lock(); defer v.mu.Unlock(); return v.filtered && !v.searching })

	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	f.WriteString(lineB + lineC)
	f.Close()
	waitFor(t, "appended entries", func() bool { return count() == 3 })
	waitFor(t, "search extended", func() bool { v.mu.Lock(); defer v.mu.Unlock(); return len(v.view) == 1 })

	// Rotation: DCS renames the journal and starts a new one.
	if err := os.Rename(path, path+".old"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(lineB), 0o644); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "rotation", func() bool { v.mu.Lock(); defer v.mu.Unlock(); return v.rotations == 1 && v.store.Len() == 1 })
	if got := v.store.Entry(0).Message; got != "beta" {
		t.Fatalf("after rotation the first entry is %q, want beta", got)
	}
	waitFor(t, "search redone on the new file", func() bool {
		v.mu.Lock()
		defer v.mu.Unlock()
		return v.filtered && !v.searching && len(v.view) == 0
	})
}
