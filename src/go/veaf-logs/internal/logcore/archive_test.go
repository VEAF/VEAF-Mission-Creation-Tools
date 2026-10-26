package logcore

import (
	"archive/zip"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// crashArchiveNames is a DCS crash archive and then some: a folder, the dump,
// the mission, dxdiag, a log in a folder, upper-case suffixes.
var crashArchiveNames = []string{
	"dxdiag.txt",
	"Logs/",
	"notes.TXT",
	"Logs/other.log",
	"dcs.20261010-163623.miz",
	"DCS.20261010-163623.log",
	"dcs-crash.txt",
	"dcs.20261010-163623.dmp",
	"zz.log",
}

func writeArchive(t *testing.T, names []string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "crash.zip")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(f)
	for _, name := range names {
		entry, err := w.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if name[len(name)-1] != '/' {
			if _, err := entry.Write([]byte("2026-08-31 11:50:40.872 ERROR   APP (Main): content of " + name + "\n")); err != nil {
				t.Fatal(err)
			}
		}
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	return path
}

// The order is the one Python's `archive_members` gives for the same names,
// measured on 2026-10-24: logs before text files, `dcs.`/`dcs-` first, stable otherwise.
func TestArchiveMembersInPythonOrder(t *testing.T) {
	got, err := ArchiveMembers(writeArchive(t, crashArchiveNames))
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"DCS.20261010-163623.log", "Logs/other.log", "zz.log", "dcs-crash.txt", "dxdiag.txt", "notes.TXT"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("members\n got: %v\nwant: %v", got, want)
	}
}

func TestArchiveOpensTheFirstMemberByDefault(t *testing.T) {
	path := writeArchive(t, crashArchiveNames)
	a, err := OpenArchive(path, "")
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	if a.Member != "DCS.20261010-163623.log" {
		t.Errorf("member %q", a.Member)
	}
	if a.DisplayName() != "crash.zip : DCS.20261010-163623.log" {
		t.Errorf("display name %q", a.DisplayName())
	}
	store := NewStore(loadRules(t), a.Buffer())
	rotated, err := a.Fetch(0)
	if rotated || err != nil {
		t.Errorf("an archive never rotates: %v, %v", rotated, err)
	}
	if n := a.Index(store, false, 0); n != 1 {
		t.Fatalf("%d entries indexed, want 1", n)
	}
	if msg := store.Entry(0).Message; msg != "content of DCS.20261010-163623.log" {
		t.Errorf("message %q", msg)
	}
	if a.Pending() {
		t.Error("an archive has nothing pending")
	}
}

func TestArchiveOpensTheChosenMember(t *testing.T) {
	a, err := OpenArchive(writeArchive(t, crashArchiveNames), "Logs/other.log")
	if err != nil {
		t.Fatal(err)
	}
	if a.DisplayName() != "crash.zip : other.log" {
		t.Errorf("display name %q: the member's base name", a.DisplayName())
	}
	if string(a.Buffer().Slice(0, a.Buffer().Size())) == "" {
		t.Error("empty member")
	}
}

func TestArchiveMemberMissing(t *testing.T) {
	if _, err := OpenArchive(writeArchive(t, crashArchiveNames), "absent.log"); err == nil {
		t.Error("a member that is not in the archive must be an error")
	}
}

func TestArchiveWithoutALog(t *testing.T) {
	_, err := OpenArchive(writeArchive(t, []string{"dcs.dmp", "mission.miz", "Logs/"}), "")
	if !errors.Is(err, ErrNoLogInArchive) {
		t.Errorf("want ErrNoLogInArchive, got %v", err)
	}
}

func TestArchiveUnreadable(t *testing.T) {
	path := filepath.Join(t.TempDir(), "broken.zip")
	if err := os.WriteFile(path, []byte("not a zip"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := ArchiveMembers(path); err == nil {
		t.Error("an unreadable archive must be an error")
	}
}

func TestIsArchive(t *testing.T) {
	for path, want := range map[string]bool{"a.zip": true, "B.ZIP": true, "dcs.log": false, "dcs.log.old": false, "zip": false} {
		if IsArchive(path) != want {
			t.Errorf("IsArchive(%q) != %v", path, want)
		}
	}
}
