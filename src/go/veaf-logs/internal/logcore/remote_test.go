package logcore

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"strings"
	"testing"
	"time"
)

// fakeRemote is an in-memory SFTP server for one file.
type fakeRemote struct {
	data    []byte
	missing bool
	broken  bool // every call fails, like a dead connection
	opens   int
}

type fakeFile struct{ *bytes.Reader }

func (fakeFile) Close() error { return nil }

func (f *fakeRemote) Size(string) (int64, error) {
	if f.broken {
		return 0, errors.New("connection reset")
	}
	if f.missing {
		return 0, fs.ErrNotExist
	}
	return int64(len(f.data)), nil
}

func (f *fakeRemote) Open(string) (RemoteFile, error) {
	f.opens++
	if f.broken {
		return nil, errors.New("connection reset")
	}
	if f.missing {
		return nil, fs.ErrNotExist
	}
	return fakeFile{bytes.NewReader(append([]byte(nil), f.data...))}, nil
}

type fakeConn struct{ closed int }

func (c *fakeConn) Close() error { c.closed++; return nil }

func newRemote(t *testing.T, remote *fakeRemote) (*RemoteSource, *Store, *fakeConn, *time.Time) {
	t.Helper()
	conn := &fakeConn{}
	src, err := NewRemoteSource(`C:\x\Logs\dcs.log`, "veaf@host:C:/x/Logs/dcs.log", func() (SFTPClient, io.Closer, error) { return remote, conn, nil })
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(src.Close)
	clock := time.Unix(1_000_000, 0)
	src.now = func() time.Time { return clock }
	return src, NewStore(loadRules(t), src.Buffer()), conn, &clock
}

func lines(n int, tag string) string {
	var sb strings.Builder
	for i := 0; i < n; i++ {
		fmt.Fprintf(&sb, "2026-08-31 11:50:%02d.000 INFO    APP (Main): %s %d\n", i%60, tag, i)
	}
	return sb.String()
}

func TestSFTPPath(t *testing.T) {
	for in, want := range map[string]string{
		`C:\Users\veaf\dcs.log`: "/C:/Users/veaf/dcs.log",
		"C:/Users/veaf/dcs.log": "/C:/Users/veaf/dcs.log",
		"/var/log/dcs.log":      "/var/log/dcs.log",
	} {
		if got := SFTPPath(in); got != want {
			t.Errorf("SFTPPath(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestRemoteMirrorsAndFollows(t *testing.T) {
	remote := &fakeRemote{data: []byte(lines(3, "a"))}
	src, store, _, _ := newRemote(t, remote)

	added, rotated, err := src.Poll(store, 0)
	if err != nil || rotated || added != 3 || store.Len() != 3 {
		t.Fatalf("first poll: added=%d rotated=%v err=%v", added, rotated, err)
	}
	remote.data = append(remote.data, lines(2, "b")...)
	added, rotated, err = src.Poll(store, 0)
	if err != nil || rotated || added != 2 || store.Len() != 5 {
		t.Fatalf("append: added=%d rotated=%v err=%v", added, rotated, err)
	}
	if got := store.Entry(4).Message; got != "b 1" {
		t.Fatalf("last entry %q", got)
	}
}

func TestRemoteUpToDateCostsNoOpen(t *testing.T) {
	remote := &fakeRemote{data: []byte(lines(3, "a"))}
	src, store, _, _ := newRemote(t, remote)
	src.Poll(store, 0)
	opens := remote.opens
	src.Poll(store, 0)
	if remote.opens != opens {
		t.Fatalf("a poll with nothing new opened the remote file again (%d -> %d)", opens, remote.opens)
	}
}

func TestRemoteRotationShorterAndLonger(t *testing.T) {
	remote := &fakeRemote{data: []byte(lines(5, "old"))}
	src, store, _, _ := newRemote(t, remote)
	src.Poll(store, 0)

	remote.data = []byte(lines(2, "new")) // DCS restarted: shorter file
	_, rotated, err := src.Poll(store, 0)
	if err != nil || !rotated || store.Len() != 2 || store.Entry(0).Message != "new 0" {
		t.Fatalf("shorter: rotated=%v err=%v len=%d", rotated, err, store.Len())
	}

	// Longer than the mirror but another file: the head fingerprint tells.
	// (A rewrite of exactly the same size is not seen remotely: like the Python
	// side, an unchanged size costs no round trip beyond the stat.)
	remote.data = []byte(lines(5, "NEW"))
	_, rotated, _ = src.Poll(store, 0)
	if !rotated || store.Len() != 5 || store.Entry(0).Message != "NEW 0" {
		t.Fatalf("a replaced longer file not detected (rotated=%v len=%d)", rotated, store.Len())
	}
}

func TestRemoteGrowthIsNotRotationBelowTheFingerprint(t *testing.T) {
	remote := &fakeRemote{data: []byte(lines(1, "a"))}
	src, store, _, _ := newRemote(t, remote)
	src.Poll(store, 0)
	for i := 0; i < 3; i++ {
		remote.data = append(remote.data, lines(1, "b")...)
		if _, rotated, _ := src.Poll(store, 0); rotated {
			t.Fatalf("append %d taken for a rotation", i)
		}
	}
	if store.Len() != 4 {
		t.Fatalf("len=%d", store.Len())
	}
}

func TestRemoteDownloadIsBounded(t *testing.T) {
	big := lines(200_000, "x") // ~ 12 MB: more than one sync chunk
	remote := &fakeRemote{data: []byte(big)}
	src, store, _, _ := newRemote(t, remote)

	if _, _, err := src.Poll(store, 0); err != nil {
		t.Fatal(err)
	}
	if src.Buffer().Size() >= int64(len(big)) || !src.Pending() {
		t.Fatalf("the first poll fetched %d of %d bytes: not bounded", src.Buffer().Size(), len(big))
	}
	for i := 0; i < 10 && (src.Pending() || store.IndexedBytes() < src.Buffer().Size()); i++ {
		if _, _, err := src.Poll(store, 0); err != nil {
			t.Fatal(err)
		}
	}
	if store.Len() != 200_000 || src.Pending() {
		t.Fatalf("len=%d pending=%v after catching up", store.Len(), src.Pending())
	}
}

func TestRemoteMissingFileIsNotAReconnection(t *testing.T) {
	remote := &fakeRemote{missing: true}
	src, store, conn, _ := newRemote(t, remote)
	_, _, err := src.Poll(store, 0)
	if !errors.Is(err, ErrRemoteFileMissing) || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v, want ErrRemoteFileMissing", err)
	}
	if conn.closed != 0 {
		t.Fatal("the connection was dropped for a missing file: the server answered")
	}
	remote.missing = false
	remote.data = []byte(lines(2, "back"))
	if added, _, err := src.Poll(store, 0); err != nil || added != 2 {
		t.Fatalf("after the file came back: added=%d err=%v", added, err)
	}
}

func TestRemoteReconnectsAfterAFailureWithADelay(t *testing.T) {
	remote := &fakeRemote{data: []byte(lines(2, "a"))}
	src, store, conn, clock := newRemote(t, remote)
	src.Poll(store, 0)

	remote.broken = true
	if _, _, err := src.Poll(store, 0); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
	if conn.closed != 1 {
		t.Fatalf("a failed sync must drop the connection (closed=%d)", conn.closed)
	}
	remote.broken = false
	if _, _, err := src.Poll(store, 0); err == nil || !strings.Contains(err.Error(), "retry in") {
		t.Fatalf("within the delay the poll must wait, got %v", err)
	}
	*clock = clock.Add(retryDelay + time.Second)
	remote.data = append(remote.data, lines(1, "b")...)
	added, _, err := src.Poll(store, 0)
	if err != nil || added != 1 || store.Len() != 3 {
		t.Fatalf("after the delay: added=%d err=%v len=%d (the mirror must survive the reconnection)", added, err, store.Len())
	}
}

func TestRemoteConnectFailureIsRetriedLater(t *testing.T) {
	calls := 0
	src, err := NewRemoteSource("/x", "h:/x", func() (SFTPClient, io.Closer, error) {
		calls++
		return nil, nil, errors.New("connection refused")
	})
	if err != nil {
		t.Fatal(err)
	}
	defer src.Close()
	store := NewStore(loadRules(t), src.Buffer())
	src.Poll(store, 0)
	src.Poll(store, 0)
	if calls != 1 {
		t.Fatalf("connect called %d times within the retry delay, want 1", calls)
	}
}
