package logcore

import (
	"archive/zip"
	"errors"
	"fmt"
	"io"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// DCS crash archives also hold the memory dump, the mission and the dxdiag
// report: only the logs are offered (port of tailer.py).
var (
	archiveLogSuffixes = []string{".log", ".txt"}
	archivePreferred   = []string{"dcs.", "dcs-"}
)

// ErrNoLogInArchive means the archive holds nothing that looks like a log.
var ErrNoLogInArchive = errors.New("no log in the archive")

// IsArchive tells whether a path is opened as an archive rather than followed.
func IsArchive(p string) bool { return strings.EqualFold(filepath.Ext(p), ".zip") }

// ArchiveMembers lists the logs of an archive, the most likely first: a `.log`
// before a `.txt`, then a `dcs.`/`dcs-` name, the archive's order otherwise.
func ArchiveMembers(archive string) ([]string, error) {
	r, err := zip.OpenReader(archive)
	if err != nil {
		return nil, err
	}
	defer r.Close()
	var names []string
	for _, f := range r.File {
		lower := strings.ToLower(f.Name)
		if strings.HasSuffix(f.Name, "/") || !hasAnySuffix(lower, archiveLogSuffixes) {
			continue
		}
		names = append(names, f.Name)
	}
	rank := func(name string) (int, int) {
		base := strings.ToLower(path.Base(name))
		log, preferred := 1, 1
		if strings.HasSuffix(base, ".log") {
			log = 0
		}
		if hasAnyPrefix(base, archivePreferred) {
			preferred = 0
		}
		return log, preferred
	}
	sort.SliceStable(names, func(i, j int) bool {
		li, pi := rank(names[i])
		lj, pj := rank(names[j])
		return li < lj || (li == lj && pi < pj)
	})
	return names, nil
}

func hasAnySuffix(s string, suffixes []string) bool {
	for _, x := range suffixes {
		if strings.HasSuffix(s, x) {
			return true
		}
	}
	return false
}

func hasAnyPrefix(s string, prefixes []string) bool {
	for _, x := range prefixes {
		if strings.HasPrefix(s, x) {
			return true
		}
	}
	return false
}

// ArchiveSource is a log read out of an archive: a snapshot, never followed,
// never rotated. It is a Follower so the window opens it like any journal.
type ArchiveSource struct {
	Path   string
	Member string
	buf    *BytesBuffer
}

// OpenArchive reads a member of an archive into memory; an empty member is the
// most likely log (ArchiveMembers' first).
func OpenArchive(archive, member string) (*ArchiveSource, error) {
	if member == "" {
		members, err := ArchiveMembers(archive)
		if err != nil {
			return nil, err
		}
		if len(members) == 0 {
			return nil, fmt.Errorf("%w %s", ErrNoLogInArchive, filepath.Base(archive))
		}
		member = members[0]
	}
	r, err := zip.OpenReader(archive)
	if err != nil {
		return nil, err
	}
	defer r.Close()
	// By exact name rather than `r.Open`, which applies io/fs path rules Python's `archive.read` does not.
	for _, f := range r.File {
		if f.Name != member {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return nil, err
		}
		defer rc.Close()
		data, err := io.ReadAll(rc)
		if err != nil {
			return nil, err
		}
		return &ArchiveSource{Path: archive, Member: member, buf: &BytesBuffer{Data: data}}, nil
	}
	return nil, fmt.Errorf("%q is not in %s", member, filepath.Base(archive))
}

// DisplayName is the tab title: the archive and the member's base name.
func (a *ArchiveSource) DisplayName() string {
	return filepath.Base(a.Path) + " : " + path.Base(a.Member)
}

func (a *ArchiveSource) Buffer() Buffer { return a.buf }

// Fetch never reports a rotation: nothing is ever added to an archive.
func (a *ArchiveSource) Fetch(int64) (bool, error) { return false, nil }

func (a *ArchiveSource) Index(store *Store, _ bool, maxBytes int64) int {
	return store.IndexNew(maxBytes)
}

func (a *ArchiveSource) Pending() bool { return false }

// PollInterval is zero: an archive is not followed, the window does not poll it.
func (a *ArchiveSource) PollInterval() time.Duration { return 0 }

func (a *ArchiveSource) Close() {}
