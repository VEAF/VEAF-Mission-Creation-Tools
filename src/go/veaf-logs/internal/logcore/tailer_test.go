package logcore

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const l1 = "2026-08-31 11:50:40.872 ERROR   APP (Main): first\n"
const l2 = "2026-08-31 11:50:41.000 INFO    APP (Main): second\n"
const l3 = "2026-08-31 11:50:42.000 INFO    APP (Main): third\n"

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func newTailed(t *testing.T, content string) (*Tailer, *Store, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "dcs.log")
	write(t, path, content)
	tailer, err := OpenTailer(path)
	if err != nil {
		t.Fatal(err)
	}
	store := NewStore(loadRules(t), tailer.Buffer)
	store.IndexNew(0)
	return tailer, store, path
}

func TestTailAppend(t *testing.T) {
	tailer, store, path := newTailed(t, l1)
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	f.WriteString(l2)
	f.Close()
	added, rotated, err := tailer.Poll(store, 0)
	if err != nil || rotated || added != 1 || store.Len() != 2 {
		t.Fatalf("added=%d rotated=%v err=%v len=%d", added, rotated, err, store.Len())
	}
}

func TestTailRotationRenameAndNewFile(t *testing.T) {
	tailer, store, path := newTailed(t, l1+l2)
	if err := os.Rename(path, path+".old"); err != nil {
		t.Fatal(err)
	}
	if _, _, err := tailer.Poll(store, 0); err != ErrUnavailable {
		t.Fatalf("a missing file must be reported as unavailable, got %v", err)
	}
	if store.Len() != 2 {
		t.Fatal("nothing must be lost while the file is absent")
	}
	write(t, path, l3)
	added, rotated, err := tailer.Poll(store, 0)
	if err != nil || !rotated || added != 1 || store.Len() != 1 {
		t.Fatalf("added=%d rotated=%v err=%v len=%d", added, rotated, err, store.Len())
	}
	if got := store.Entry(0).Message; got != "third" {
		t.Fatalf("after rotation the first entry is %q", got)
	}
}

func TestTailTruncation(t *testing.T) {
	tailer, store, path := newTailed(t, l1+l2+l3)
	write(t, path, l1)
	_, rotated, _ := tailer.Poll(store, 0)
	if !rotated || store.Len() != 1 {
		t.Fatalf("rotated=%v len=%d", rotated, store.Len())
	}
}

func TestTailRewriteSameSize(t *testing.T) {
	tailer, store, path := newTailed(t, l1)
	write(t, path, strings.Replace(l1, "first", "FIRST", 1)) // same size, other content
	_, rotated, _ := tailer.Poll(store, 0)
	if !rotated {
		t.Fatal("a same-size rewrite must be detected through the head fingerprint")
	}
	if got := store.Entry(0).Message; got != "FIRST" {
		t.Fatalf("message %q", got)
	}
}

func TestTailGrowthIsNotRotation(t *testing.T) {
	// While the file is shorter than the fingerprint, each write lengthens it:
	// that must not look like a rewrite (the error the Python docstring warns about).
	tailer, store, path := newTailed(t, l1)
	for i := 0; i < 3; i++ {
		f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
		f.WriteString(l2)
		f.Close()
		if _, rotated, _ := tailer.Poll(store, 0); rotated {
			t.Fatalf("append %d taken for a rotation", i)
		}
	}
	if store.Len() != 4 {
		t.Fatalf("len=%d", store.Len())
	}
}
