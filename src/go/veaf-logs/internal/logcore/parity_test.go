package logcore

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// The reference catalogue is the Python one, unchanged.
const rulesPath = "../../../../python/veaf-tools/veaf_logs/rules.json"

func loadRules(t *testing.T) *Rules {
	t.Helper()
	r, err := LoadRules(rulesPath)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

// TestParityWithPython indexes each corpus file with the Go core and compares,
// entry by entry, with the golden dump written by the Python implementation
// (testdata/gen_golden.py): level, source, label, module, noise families,
// timestamp, subsystem, message, number of continuation lines, then the
// counters per level, source and noise family.
func TestParityWithPython(t *testing.T) {
	rules := loadRules(t)
	files, err := filepath.Glob("../../testdata/corpus/*.log")
	if err != nil || len(files) == 0 {
		t.Fatalf("no corpus found: %v", err)
	}
	for _, file := range files {
		name := strings.TrimSuffix(filepath.Base(file), ".log")
		t.Run(name, func(t *testing.T) {
			data, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			store := NewStore(rules, &BytesBuffer{Data: data})
			store.IndexNew(0)

			golden, err := os.Open("../../testdata/golden/" + name + ".jsonl")
			if err != nil {
				t.Fatal(err)
			}
			defer golden.Close()
			scanner := bufio.NewScanner(golden)
			scanner.Buffer(make([]byte, 1<<20), 1<<20)
			i, bad := 0, 0
			for scanner.Scan() {
				var want DumpRecord
				if err := json.Unmarshal(scanner.Bytes(), &want); err != nil {
					t.Fatal(err)
				}
				if i >= store.Len() {
					t.Fatalf("Go indexed %d entries, Python at least %d", store.Len(), i+1)
				}
				if want.Noise == nil {
					want.Noise = []string{}
				}
				got := Record(store.Entry(i))
				if !reflect.DeepEqual(want, got) {
					bad++
					if bad <= 5 {
						t.Errorf("entry %d differs\n python: %+v\n     go: %+v", i, want, got)
					}
				}
				i++
			}
			if i != store.Len() {
				t.Errorf("Python indexed %d entries, Go %d", i, store.Len())
			}

			raw, err := os.ReadFile("../../testdata/golden/" + name + ".counts.json")
			if err != nil {
				t.Fatal(err)
			}
			var counts map[string]map[string]int
			if err := json.Unmarshal(raw, &counts); err != nil {
				t.Fatal(err)
			}
			for what, got := range map[string]map[string]int{
				"level": store.CountsByLevel(), "source": store.CountsBySource(), "noise": store.CountsByNoise()} {
				if !reflect.DeepEqual(counts[what], got) {
					t.Errorf("counters by %s differ\n python: %v\n     go: %v", what, counts[what], got)
				}
			}
		})
	}
}

// A parity test that cannot fail proves nothing: the same comparison must
// reject a corrupted golden.
func TestParityCanFail(t *testing.T) {
	rules := loadRules(t)
	store := NewStore(rules, &BytesBuffer{Data: []byte("2026-08-31 11:50:40.872 ERROR   APP (Main): x\n")})
	store.IndexNew(0)
	got := Record(store.Entry(0))
	want := got
	want.Level = "INFO"
	if reflect.DeepEqual(want, got) {
		t.Fatal("comparison does not see a different level")
	}
	if got.Level != "ERROR" || got.Subsystem != "APP" || got.Message != "x" {
		t.Fatalf("unexpected record %+v", got)
	}
}

// Appending to a journal indexes only the new complete lines, like the Python tail.
func TestIndexIsIncremental(t *testing.T) {
	rules := loadRules(t)
	buf := &BytesBuffer{Data: []byte("2026-08-31 11:50:40.872 ERROR   APP (Main): a\n2026-08-31 11:50:41.000 INFO    APP (Main): b")}
	store := NewStore(rules, buf)
	if n := store.IndexNew(0); n != 1 {
		t.Fatalf("first pass: %d entries, want 1 (last line incomplete)", n)
	}
	buf.Data = append(buf.Data, []byte("\nstack traceback:\n")...)
	if n := store.IndexNew(0); n != 1 {
		t.Fatalf("second pass: %d entries, want 1", n)
	}
	if got := len(store.Entry(1).Continuation); got != 1 {
		t.Fatalf("continuations of entry 1: %d, want 1", got)
	}
}

// The embedded catalogue is a copy: the Python file stays the single source and
// this test fails as soon as the two drift apart.
func TestEmbeddedRulesAreThePythonOnes(t *testing.T) {
	python, err := os.ReadFile(rulesPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(python, embeddedRules) {
		t.Fatal("internal/logcore/rules.json differs from veaf_logs/rules.json: copy it again")
	}
}

// maxBytes bounds the work of one call, not what it can read: a line longer
// than the slice must still be indexed (the viewer indexes in 1 MB slices, the
// Python reads 8 MB chunks).
func TestIndexNewReadsALineLongerThanTheSlice(t *testing.T) {
	rules := loadRules(t)
	long := "2026-08-31 11:50:40.872 INFO    APP (Main): " + strings.Repeat("x", 3<<20) + "\n"
	buf := &BytesBuffer{Data: []byte(long + "2026-08-31 11:50:41.000 INFO    APP (Main): after\n")}
	store := NewStore(rules, buf)
	for i := 0; i < 20 && store.IndexedBytes() < buf.Size(); i++ {
		store.IndexNew(1 << 20)
	}
	if store.Len() != 2 || store.IndexedBytes() != buf.Size() {
		t.Fatalf("entries=%d indexed=%d of %d: indexing stalled on the long line", store.Len(), store.IndexedBytes(), buf.Size())
	}
}

// A snapshot must not see a continuation line added to the last entry later:
// the live index grows that entry in place while a search reads the snapshot.
func TestSnapshotIsIsolatedFromLaterContinuations(t *testing.T) {
	rules := loadRules(t)
	buf := &BytesBuffer{Data: []byte("2026-08-31 11:50:40.872 ERROR   APP (Main): head\nfirst\n")}
	store := NewStore(rules, buf)
	store.IndexNew(0)
	snap := store.Snapshot()
	before := snap.length[0]
	buf.Data = append(buf.Data, []byte("stack traceback:\n")...)
	store.IndexNew(0)
	if store.length[0] == before {
		t.Fatal("test premise: the live entry should have grown")
	}
	if snap.length[0] != before {
		t.Fatalf("snapshot length changed from %d to %d", before, snap.length[0])
	}
	if got := snap.Search("traceback", nil); len(got) != 0 {
		t.Fatalf("the snapshot found text added after it was taken: %v", got)
	}
}
