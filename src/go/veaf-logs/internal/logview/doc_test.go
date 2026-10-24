package logview

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
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
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timeout waiting for %s", what)
}

func rules(t *testing.T) *logcore.Rules {
	t.Helper()
	r, err := logcore.DefaultRules()
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func localDoc(t *testing.T, content string) (*Doc, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "dcs.log")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	tailer, err := logcore.OpenTailer(path)
	if err != nil {
		t.Fatal(err)
	}
	d := NewDoc(rules(t), tailer, true)
	t.Cleanup(d.Close)
	return d, path
}

// The poll loop wires the file to the window: appended lines arrive, a filter
// in force applies to them, and a rotation starts over on the new file.
func TestFollowsAppendsAndRotation(t *testing.T) {
	d, path := localDoc(t, lineA)
	d.Start()
	waitFor(t, "first entry", func() bool { return d.Status().Total == 1 })

	f := logcore.NewFilterSet()
	f.TextFilters = []logcore.TextFilter{{Pattern: "gamma"}}
	if err := d.SetFilters(f); err != nil {
		t.Fatal(err)
	}
	if d.Rows() != 0 {
		t.Fatalf("no gamma yet, %d rows", d.Rows())
	}

	file, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	file.WriteString(lineB + lineC)
	file.Close()
	waitFor(t, "appended entries", func() bool { return d.Status().Total == 3 })
	waitFor(t, "the filter applies to them", func() bool { return d.Rows() == 1 })
	if e, _ := d.Entry(0); e.Message != "gamma" {
		t.Fatalf("filtered row: %q", e.Message)
	}

	if err := os.Rename(path, path+".old"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(lineB), 0o644); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "rotation", func() bool { s := d.Status(); return s.Rotations == 1 && s.Total == 1 })
	if d.Rows() != 0 {
		t.Errorf("after rotation, no gamma: %d rows", d.Rows())
	}
}

// A stack trace that arrives after its error line must reach the row already shown.
func TestLateStackTraceReachesTheShownRow(t *testing.T) {
	d, path := localDoc(t, "2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error\n")
	d.Start()
	waitFor(t, "error line", func() bool { return d.Rows() == 1 })
	if e, _ := d.Entry(0); len(e.Continuation) != 0 {
		t.Fatal("no trace yet")
	}
	file, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	file.WriteString("stack traceback:\n\t[C]: in function 'x'\n")
	file.Close()
	waitFor(t, "trace attached", func() bool { e, _ := d.Entry(0); return len(e.Continuation) == 2 })
}

// The table appends when rows are appended and reloads when they are replaced.
func TestResetsCountReplacementsNotAppends(t *testing.T) {
	d, path := localDoc(t, lineA)
	d.Start()
	waitFor(t, "first entry", func() bool { return d.Status().Total == 1 })
	file, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	file.WriteString(lineB)
	file.Close()
	waitFor(t, "appended", func() bool { return d.Rows() == 2 })
	if d.Resets() != 0 {
		t.Fatalf("an append is no reset: %d", d.Resets())
	}
	f := logcore.NewFilterSet()
	f.Levels = map[string]logcore.State{"INFO": logcore.StateOff}
	d.SetFilters(f)
	if d.Resets() != 1 || d.Rows() != 1 {
		t.Fatalf("new filters reload: resets %d, rows %d", d.Resets(), d.Rows())
	}
	d.SetFilters(logcore.NewFilterSet())
	if d.Resets() != 2 || d.Rows() != 2 {
		t.Fatalf("filters removed reload: resets %d, rows %d", d.Resets(), d.Rows())
	}
}

func TestDirtyIsReportedOnce(t *testing.T) {
	d, _ := localDoc(t, lineA)
	d.Start()
	waitFor(t, "dirty", d.Dirty)
	waitFor(t, "indexed", func() bool { return !d.Status().Indexing })
	d.Dirty()
	time.Sleep(50 * time.Millisecond)
	if d.Dirty() {
		t.Error("nothing changed, nothing to redraw")
	}
}

func TestInvalidPatternChangesNothing(t *testing.T) {
	d, _ := localDoc(t, lineA)
	f := logcore.NewFilterSet()
	f.TextFilters = []logcore.TextFilter{{Pattern: "[non fermee", Mode: logcore.ModeRegex}}
	if err := d.SetFilters(f); err == nil {
		t.Fatal("an invalid regex must be refused")
	}
	if f := d.Filters(); !f.IsEmpty() {
		t.Error("the filters in force are unchanged")
	}
}

func TestCancelStopsIndexingAndFollowing(t *testing.T) {
	d, _ := localDoc(t, strings.Repeat(lineA, 200_000)) // ~10 MB: several slices
	d.Cancel()
	d.Start()
	waitFor(t, "stopped", func() bool { return !d.Status().Indexing })
	s := d.Status()
	if !s.Cancelled || s.Indexed >= s.Size {
		t.Errorf("cancelled before the end: %+v", s)
	}
	if FollowText(true, true, s) != "indexation interrompue (pas de suivi)" {
		t.Error(FollowText(true, true, s))
	}
}

func TestArchiveIsIndexedThenLeftAlone(t *testing.T) {
	src := &countingSource{BytesBuffer: &logcore.BytesBuffer{Data: []byte(lineA + lineB)}}
	d := NewDoc(rules(t), src, false)
	defer d.Close()
	d.Start()
	waitFor(t, "indexed", func() bool { return d.Status().Total == 2 && !d.Status().Indexing })
	before := src.fetches.Load()
	time.Sleep(50 * time.Millisecond)
	if src.fetches.Load() != before {
		t.Error("an archive is not polled once indexed")
	}
}

// countingSource is an in-memory journal that counts how often it is polled.
type countingSource struct {
	*logcore.BytesBuffer
	fetches atomic.Int64
}

func (s *countingSource) Buffer() logcore.Buffer                       { return s.BytesBuffer }
func (s *countingSource) Fetch(int64) (bool, error)                    { s.fetches.Add(1); return false, nil }
func (s *countingSource) Pending() bool                                { return false }
func (s *countingSource) PollInterval() time.Duration                  { return time.Millisecond }
func (s *countingSource) Close()                                       {}
func (s *countingSource) Index(st *logcore.Store, _ bool, n int64) int { return st.IndexNew(n) }

// slowSource blocks in Fetch, like a remote journal waiting for the network.
type slowSource struct {
	entered chan struct{}
	release chan struct{}
}

func (s *slowSource) Buffer() logcore.Buffer { return &logcore.BytesBuffer{} }
func (s *slowSource) Fetch(int64) (bool, error) {
	select {
	case s.entered <- struct{}{}:
	default:
	}
	<-s.release
	return false, nil
}
func (s *slowSource) Index(*logcore.Store, bool, int64) int { return 0 }
func (s *slowSource) Pending() bool                         { return false }
func (s *slowSource) PollInterval() time.Duration           { return 10 * time.Millisecond }
func (s *slowSource) Close()                                {}

// The window takes the document's lock for every visible row: a remote fetch
// (connection, download) must never hold it, or the window freezes with the network.
func TestTheNetworkDoesNotHoldTheLock(t *testing.T) {
	src := &slowSource{entered: make(chan struct{}, 1), release: make(chan struct{})}
	defer close(src.release)
	d := NewDoc(rules(t), src, true)
	d.Start()
	select {
	case <-src.entered:
	case <-time.After(5 * time.Second):
		t.Fatal("Fetch was never called")
	}
	done := make(chan struct{})
	go func() { d.Rows(); close(done) }()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("the lock is held while Fetch waits for the network")
	}
}

func TestStatusTexts(t *testing.T) {
	if got := (Status{Total: 10, Shown: 10}).CountsText(); got != "10 lignes affichées sur 10" {
		t.Error(got)
	}
	if got := (Status{Total: 10, Shown: 4}).CountsText(); got != "4 lignes affichées sur 10   —   6 masquées par les filtres" {
		t.Error(got)
	}
	if FollowText(false, true, Status{}) != "archive (pas de suivi)" || FollowText(true, true, Status{}) != "suivi actif" || FollowText(true, false, Status{}) != "suivi en pause" {
		t.Error("follow texts")
	}
	if (Status{Indexed: 25, Size: 100}).Percent() != 25 || (Status{}).Percent() != 100 {
		t.Error("percent")
	}
}

// rulesWithSource is the embedded catalogue plus a source recognising messages
// that start with `prefix`: what a user adds to rules.json before pressing F5.
func rulesWithSource(t *testing.T, id, prefix string) *logcore.Rules {
	t.Helper()
	var raw map[string]any
	if err := json.Unmarshal(logcore.EmbeddedRules(), &raw); err != nil {
		t.Fatal(err)
	}
	raw["sources"] = append([]any{map[string]any{"id": id, "label": id, "color": "#ff8800", "match": "^" + prefix}}, raw["sources"].([]any)...)
	data, _ := json.Marshal(raw)
	r, err := logcore.ParseRules(data)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

// F5: the journal is indexed again with the new catalogue, even when its
// goroutine was over — an archive, an interrupted indexing — and the filters stay.
func TestReclassifyReindexesWithTheNewCatalogue(t *testing.T) {
	src := &countingSource{BytesBuffer: &logcore.BytesBuffer{Data: []byte(lineA + lineB + lineC)}}
	archive := NewDoc(rules(t), src, false)
	defer archive.Close()
	archive.Start()
	waitFor(t, "archive indexed", func() bool { return archive.Status().Total == 3 && !archive.Status().Indexing })
	f := logcore.NewFilterSet()
	f.TextFilters = []logcore.TextFilter{{Pattern: "beta", Invert: true}}
	archive.SetFilters(f)

	cancelled, _ := localDoc(t, strings.Repeat(lineA, 200_000))
	cancelled.Cancel()
	cancelled.Start()
	waitFor(t, "cancelled", func() bool { return !cancelled.Status().Indexing })

	newRules := rulesWithSource(t, "alphasrc", "alpha")
	for name, d := range map[string]*Doc{"archive": archive, "cancelled": cancelled} {
		resets := d.Resets()
		d.Reclassify(newRules)
		waitFor(t, name+" reindexed", func() bool { s := d.Status(); return !s.Indexing && s.Indexed == s.Size })
		if d.Rules != newRules || d.Counts().Sources["alphasrc"] == 0 || d.Status().Cancelled || d.Resets() == resets {
			t.Errorf("%s: not reclassified: sources=%v status=%+v", name, d.Counts().Sources, d.Status())
		}
	}
	if f := archive.Filters(); archive.Rows() != 2 || f.IsEmpty() {
		t.Errorf("the filters in force must apply to the new index: %d rows", archive.Rows())
	}
}

// A journal whose last line has no newline yet (DCS mid-write, a log cut by a
// crash) keeps that line for later: the indexing is over all the same. It used
// to stay "indexing" forever, its goroutine polling every millisecond — 18 % of
// a core per such tab, measured 2026-10-24.
func TestAnIncompleteLastLineEndsTheIndexing(t *testing.T) {
	d, path := localDoc(t, lineA+"2026-08-31 11:50:41.000 INFO    APP (Main): no newline")
	d.Start()
	waitFor(t, "indexing over", func() bool { s := d.Status(); return s.Total == 1 && !s.Indexing })

	// The line completes: it arrives as the follow polls.
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	f.WriteString("\n")
	f.Close()
	waitFor(t, "completed line", func() bool { return d.Status().Total == 2 })
}
