package logcore

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"regexp"
	"strings"
	"sync/atomic"
	"time"
)

// Follower is a journal that can be followed: a local file (Tailer) or a remote
// one mirrored over SFTP (RemoteSource). The window only knows this.
type Follower interface {
	// Buffer is where the index reads its bytes.
	Buffer() Buffer
	// Fetch brings the bytes up to date and tells whether the journal was
	// replaced; `indexed` is what the index already holds. It may take long
	// (network), so it must run without holding the lock that guards the store.
	Fetch(indexed int64) (rotated bool, err error)
	// Index indexes what Fetch brought, starting over after a rotation. It only
	// reads the buffer: it is quick and runs under the store's lock.
	Index(store *Store, rotated bool, maxBytes int64) int
	// Pending tells that bytes remain to be fetched before the buffer is up to date.
	Pending() bool
	// PollInterval is the delay between two polls once up to date.
	PollInterval() time.Duration
	// Close releases what the source holds (connection, mirror file).
	Close()
}

// Close does nothing for a local file: it is never held open.
func (t *Tailer) Close() {}

// ErrRemoteFileMissing means the server answers but the journal is not there
// (instance stopped). It is an ErrUnavailable: the file will come back when the
// instance restarts, and it is not worth reconnecting every few seconds for it.
var ErrRemoteFileMissing = fmt.Errorf("%w: absent on the server", ErrUnavailable)

// RemoteFile is what is asked of an open remote file.
type RemoteFile interface {
	io.ReadSeeker
	io.Closer
}

// SFTPClient is what is asked of the SFTP client; the SSH implementation lives
// in internal/sshlog, so that this package does not depend on the network.
type SFTPClient interface {
	// Size is the size of the remote file; errors.Is(err, fs.ErrNotExist) when absent.
	Size(path string) (int64, error)
	Open(path string) (RemoteFile, error)
}

const (
	// remoteSyncChunk bounds what one Poll downloads, so that the window shows
	// progress on a big journal instead of waiting for all of it.
	remoteSyncChunk = 8 << 20
	readChunk       = 1 << 20

	// retryDelay: after a network failure, do not retry at every poll, a failing
	// SSH connection can take seconds to say so.
	retryDelay = 5 * time.Second
	// remotePollInterval: a local file is polled every 300 ms, a remote one costs a
	// network exchange per poll.
	remotePollInterval = time.Second
)

// MirrorBuffer is a local copy of a remote file, extended at each Sync.
//
// The viewer reads by offset, one read per displayed line: a network round trip
// per line would be unbearable, and a `tail -f` stream cannot be re-read at a
// given offset. Hence the mirror: Sync does one remote stat and brings back what
// was written since into a local temporary file; Slice reads that file.
type MirrorBuffer struct {
	client SFTPClient
	remote string
	path   string
	head   []byte
	// size and remoteSize are read by the window while Sync writes them.
	size atomic.Int64
	// remoteSize is the size seen at the last sync, to know what remains to fetch.
	remoteSize atomic.Int64
}

// NewMirrorBuffer creates the empty local mirror of a remote path.
func NewMirrorBuffer(client SFTPClient, remote string, dir string) (*MirrorBuffer, error) {
	f, err := os.CreateTemp(dir, "veaf-logs-*.log")
	if err != nil {
		return nil, err
	}
	f.Close()
	return &MirrorBuffer{client: client, remote: remote, path: f.Name()}, nil
}

func (m *MirrorBuffer) Size() int64    { return m.size.Load() }
func (m *MirrorBuffer) Refresh() int64 { return m.size.Load() } // the network is only touched by Sync

func (m *MirrorBuffer) Slice(start, length int64) []byte {
	if length <= 0 {
		return nil
	}
	f, err := os.Open(m.path)
	if err != nil {
		return nil
	}
	defer f.Close()
	buf := make([]byte, length)
	n, err := f.ReadAt(buf, start)
	if err != nil && err != io.EOF {
		return nil
	}
	return buf[:n]
}

// Close deletes the mirror file.
func (m *MirrorBuffer) Close() { os.Remove(m.path) }

// Pending tells whether the remote file was seen longer than the mirror.
func (m *MirrorBuffer) Pending() bool { return m.remoteSize.Load() > m.size.Load() }

// Sync brings back what was written since, at most `max` bytes (0: no bound),
// and tells whether the file was replaced. A rotation is a file that shrank or
// whose first bytes changed: the mirror then starts over.
func (m *MirrorBuffer) Sync(max int64) (rotated bool, err error) {
	remoteSize, err := m.client.Size(m.remote)
	if err != nil {
		return false, wrapRemote(m.remote, err)
	}
	m.remoteSize.Store(remoteSize)
	if remoteSize == m.size.Load() && m.size.Load() > 0 {
		return false, nil
	}
	h, err := m.client.Open(m.remote)
	if err != nil {
		return false, wrapRemote(m.remote, err)
	}
	defer h.Close()
	head := make([]byte, headBytes)
	n, err := io.ReadFull(h, head)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return false, wrapRemote(m.remote, err)
	}
	head = head[:n]
	rotated = remoteSize < m.size.Load() || headChanged(head, m.head)
	if rotated {
		if err := os.Truncate(m.path, 0); err != nil {
			return false, err
		}
		m.size.Store(0)
		m.head = nil
	}
	if remoteSize > m.size.Load() {
		want := remoteSize - m.size.Load()
		if max > 0 && want > max {
			want = max
		}
		if _, err := h.Seek(m.size.Load(), io.SeekStart); err != nil {
			return rotated, wrapRemote(m.remote, err)
		}
		if err := m.appendFrom(h, want); err != nil {
			return rotated, wrapRemote(m.remote, err)
		}
	}
	m.head = m.Slice(0, headBytes)
	return rotated, nil
}

func (m *MirrorBuffer) appendFrom(h io.Reader, want int64) error {
	f, err := os.OpenFile(m.path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		return err
	}
	defer f.Close()
	buf := make([]byte, readChunk)
	for want > 0 {
		n := int64(len(buf))
		if want < n {
			n = want
		}
		got, err := h.Read(buf[:n])
		if got > 0 {
			if _, werr := f.Write(buf[:got]); werr != nil {
				return werr
			}
			m.size.Add(int64(got))
			want -= int64(got)
		}
		if err == io.EOF {
			// Shorter than its stat said: the rest comes at the next poll.
			return nil
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func wrapRemote(path string, err error) error {
	if errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("%s: %w", path, ErrRemoteFileMissing)
	}
	return fmt.Errorf("%s: %v: %w", path, err, ErrUnavailable)
}

// SFTPPath is the SFTP form of a Windows path: `C:\x\y` becomes `/C:/x/y`.
func SFTPPath(path string) string {
	p := strings.ReplaceAll(path, "\\", "/")
	if drive.MatchString(p) {
		return "/" + p
	}
	return p
}

var drive = regexp.MustCompile(`^[A-Za-z]:`)

// Connector opens the SFTP client of a remote server (see internal/sshlog).
type Connector func() (SFTPClient, io.Closer, error)

// RemoteSource follows a remote journal: same contract as Tailer, bytes over
// SFTP. The connection opens at the first poll and reopens by itself after a
// failure, with a delay between two attempts.
type RemoteSource struct {
	Path     string // remote path as written in the configuration
	Location string // user@host:path, for messages
	connect  Connector
	mirror   *MirrorBuffer
	client   SFTPClient
	conn     io.Closer
	retryAt  time.Time
	now      func() time.Time
	dir      string
}

// NewRemoteSource creates the source; nothing touches the network before the first Poll.
func NewRemoteSource(path, location string, connect Connector) (*RemoteSource, error) {
	r := &RemoteSource{Path: path, Location: location, connect: connect, now: time.Now}
	m, err := NewMirrorBuffer(nil, SFTPPath(path), "")
	if err != nil {
		return nil, err
	}
	r.mirror = m
	return r, nil
}

func (r *RemoteSource) Buffer() Buffer              { return r.mirror }
func (r *RemoteSource) Pending() bool               { return r.mirror.Pending() }
func (r *RemoteSource) PollInterval() time.Duration { return remotePollInterval }
func (r *RemoteSource) Close()                      { r.drop(); r.mirror.Close() }

// Fetch brings back what is new (bounded) and detects a rotation.
func (r *RemoteSource) Fetch(indexed int64) (bool, error) {
	if err := r.ensureConnected(); err != nil {
		return false, err
	}
	replaced, err := r.mirror.Sync(remoteSyncChunk)
	if err != nil {
		if !errors.Is(err, ErrRemoteFileMissing) {
			r.drop() // the connection is probably dead: reconnect at the next poll
		}
		return false, err
	}
	return replaced || r.mirror.Size() < indexed, nil
}

// Index indexes the mirror, from the start after a rotation.
func (r *RemoteSource) Index(store *Store, rotated bool, maxBytes int64) int {
	if rotated {
		store.Clear()
	}
	return store.IndexNew(maxBytes)
}

// Poll is Fetch then Index, for callers that do not need to split them.
func (r *RemoteSource) Poll(store *Store, maxBytes int64) (int, bool, error) {
	return poll(r, store, maxBytes)
}

func poll(f Follower, store *Store, maxBytes int64) (int, bool, error) {
	rotated, err := f.Fetch(store.IndexedBytes())
	if err != nil {
		return 0, false, err
	}
	return f.Index(store, rotated, maxBytes), rotated, nil
}

func (r *RemoteSource) ensureConnected() error {
	if r.client != nil {
		return nil
	}
	if now := r.now(); now.Before(r.retryAt) {
		return fmt.Errorf("%s: retry in %.0f s: %w", r.Location, r.retryAt.Sub(now).Seconds(), ErrUnavailable)
	}
	client, conn, err := r.connect()
	if err != nil {
		r.retryAt = r.now().Add(retryDelay)
		return fmt.Errorf("%s: %v: %w", r.Location, err, ErrUnavailable)
	}
	r.client, r.conn = client, conn
	r.mirror.client = client // the mirror survives a reconnection, the client it held is dead
	return nil
}

func (r *RemoteSource) drop() {
	r.client = nil
	if r.conn != nil {
		r.conn.Close()
		r.conn = nil
	}
	r.retryAt = r.now().Add(retryDelay)
}
