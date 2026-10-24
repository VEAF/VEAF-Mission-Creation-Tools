package logcore

import (
	"bytes"
	"errors"
	"io"
	"os"
	"time"
)

// headBytes is the fingerprint of the start of the file, re-read at each poll
// to spot a rotation that changed neither the size nor the identity.
const headBytes = 512

// ErrUnavailable means the followed file is momentarily absent (rotation in progress).
var ErrUnavailable = errors.New("log momentarily unavailable")

// Tailer follows a journal and tells when it was replaced (port of tailer.py).
//
// DCS never truncates its journal while running: at the next launch it renames
// it to .old and starts a new file. The tailer reports when everything must be
// read again: file replaced, shorter than what was indexed, or rewritten.
type Tailer struct {
	Path string
	info os.FileInfo
	head []byte
	buf  *FileBuffer
}

// OpenTailer starts following a file.
func OpenTailer(path string) (*Tailer, error) {
	t := &Tailer{Path: path}
	if err := t.open(); err != nil {
		return nil, err
	}
	return t, nil
}

func (t *Tailer) open() error {
	info, err := os.Stat(t.Path)
	if err != nil {
		return ErrUnavailable
	}
	t.info = info
	t.head = t.readHead()
	t.buf = NewFileBuffer(t.Path)
	return nil
}

func (t *Tailer) readHead() []byte {
	f, err := os.Open(t.Path)
	if err != nil {
		return nil
	}
	defer f.Close()
	buf := make([]byte, headBytes)
	n, err := f.Read(buf)
	if err != nil && err != io.EOF {
		return nil
	}
	return buf[:n]
}

// CheckRotation tells whether the file was replaced since the last call.
// `indexed` is the number of bytes already taken into account: a shorter file
// was necessarily rewritten.
func (t *Tailer) CheckRotation(indexed int64) (bool, error) {
	info, err := os.Stat(t.Path)
	if err != nil {
		// DCS is rotating the file: wait, nothing is lost, reading resumes at the next poll.
		return false, ErrUnavailable
	}
	head := t.readHead()
	rotated := !os.SameFile(info, t.info) || info.Size() < indexed || headChanged(head, t.head)
	t.info, t.head = info, head
	return rotated, nil
}

// headChanged compares on the common length: while the journal is shorter than
// headBytes the fingerprint grows at each write without anything being rewritten.
func headChanged(head, previous []byte) bool {
	n := len(head)
	if len(previous) < n {
		n = len(previous)
	}
	return !bytes.Equal(head[:n], previous[:n])
}

// Poll indexes what is new in the file and handles rotation: after a rotation
// the store is emptied and the new file read from the start. It returns the
// number of entries added and whether a rotation happened. `maxBytes` bounds
// the work of one call (0: unbounded), so that a big file indexes in slices.
func (t *Tailer) Poll(store *Store, maxBytes int64) (added int, rotated bool, err error) {
	return poll(t, store, maxBytes)
}

// Fetch is the rotation check: a local file is read where it is, there is
// nothing to bring back.
func (t *Tailer) Fetch(indexed int64) (bool, error) { return t.CheckRotation(indexed) }

// Index indexes what is new; after a rotation the store is emptied and the new
// file read from the start.
func (t *Tailer) Index(store *Store, rotated bool, maxBytes int64) int {
	if rotated {
		store.Clear()
		t.buf = NewFileBuffer(t.Path)
		store.buffer = t.buf
	}
	return store.IndexNew(maxBytes)
}

// Buffer is the file, read on demand.
func (t *Tailer) Buffer() Buffer { return t.buf }

// Pending is always false: a local file is read where it is.
func (t *Tailer) Pending() bool { return false }

// PollInterval is how often a local file is polled.
func (t *Tailer) PollInterval() time.Duration { return 300 * time.Millisecond }
