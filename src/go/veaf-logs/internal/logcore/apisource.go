package logcore

import (
	"errors"
	"fmt"
	"strings"
	"sync/atomic"
	"time"
)

// The RestAPI of DCSServerBot reads a server's logs without SSH: entries, not
// bytes, and a cursor to get what was written since (FEAT-VEAF-LOGS-REST-API).
// APISource mirrors them into a local file, written back as lines of the log's
// own format, so that the index reads it like any other journal.

var (
	// ErrCursorRefused: the API no longer accepts the cursor; the source reads the tail again.
	ErrCursorRefused = errors.New("cursor refused by the server")
	// ErrAPIAuth: the API key was refused.
	ErrAPIAuth = errors.New("authentication refused")
	// ErrAPIUnknownLog: the server, the node or the file is not known any more.
	ErrAPIUnknownLog = errors.New("unknown log")
	// ErrAPIOtherNode: this version of the bot only reads the logs of its own node.
	ErrAPIOtherNode = errors.New("log on another node")
)

// apiLines is what one request asks for, the API's maximum.
const apiLines = 2000

// APIEntry is one entry as the API returns it: the lines that follow its header
// (a traceback) are in Text, joined with "\n". No time nor level: a line found
// before any header.
type APIEntry struct {
	Time  string `json:"time"`
	Level string `json:"level"`
	Text  string `json:"text"`
}

// APIQuery is one read: the last entries (Tail), or from the start of File, or
// what was written since Cursor.
type APIQuery struct {
	File   string // "" is the live file
	Tail   bool
	Lines  int
	Cursor string
}

// APIPage is the answer to a read.
type APIPage struct {
	Entries   []APIEntry `json:"lines"`
	Cursor    string     `json:"cursor"`
	Rotated   bool       `json:"rotated"`
	Gap       bool       `json:"gap"`
	NewFileAt *int       `json:"new_file_at"`
	More      bool       `json:"more"`
}

// APIClient reads one log through the API; the HTTP implementation lives in
// internal/apilog, so that this package does not depend on the network. Its
// errors wrap ErrUnavailable (to retry later), ErrRemoteFileMissing (no log
// yet), ErrCursorRefused, or anything else for a refusal that will not change.
type APIClient interface {
	Read(q APIQuery) (APIPage, error)
}

// APISourceOptions say which log and how to write it back.
type APISourceOptions struct {
	File string // an older file, read once from its start; "" follows the live log
	Bot  bool   // a bot log (`date time LEVEL\ttext`), else a DCS log
}

// APISource follows a log through the RestAPI: same contract as RemoteSource.
type APISource struct {
	client APIClient
	opts   APISourceOptions
	mirror *MirrorBuffer
	cursor string
	more   bool
	gaps   atomic.Int32 // read by the window while Fetch writes it
	fatal  error
	// restart remembers a mirror emptied by a page that then failed to be
	// written: the index must start over whatever the next page brings.
	restart bool
	retryAt time.Time
	now     func() time.Time
}

// NewAPISource creates the source; nothing touches the network before the first Fetch.
func NewAPISource(client APIClient, o APISourceOptions) (*APISource, error) {
	m, err := NewMirrorBuffer(nil, "", "")
	if err != nil {
		return nil, err
	}
	return &APISource{client: client, opts: o, mirror: m, now: time.Now}, nil
}

func (a *APISource) Buffer() Buffer              { return a.mirror }
func (a *APISource) Pending() bool               { return a.more }
func (a *APISource) PollInterval() time.Duration { return remotePollInterval }
func (a *APISource) Close()                      { a.mirror.Close() }

// Gaps counts the rotations after which the API could not find the end of the
// old file: lines were lost.
func (a *APISource) Gaps() int { return int(a.gaps.Load()) }

// Open reads the first entries, so that opening a tab tells at once whether the
// log can be reached. It touches the network: never from the window's thread.
func (a *APISource) Open() error {
	_, err := a.Fetch(0)
	return err
}

// Fetch brings back what is new and tells whether the journal was replaced.
func (a *APISource) Fetch(int64) (bool, error) {
	if a.fatal != nil {
		return false, a.fatal
	}
	if now := a.now(); now.Before(a.retryAt) {
		return false, fmt.Errorf("retry in %.0f s: %w", a.retryAt.Sub(now).Seconds(), ErrUnavailable)
	}
	started := a.cursor == ""
	page, err := a.client.Read(a.query())
	if errors.Is(err, ErrCursorRefused) && !started {
		a.cursor, started = "", true
		page, err = a.client.Read(a.query())
	}
	if err != nil {
		if errors.Is(err, ErrUnavailable) {
			a.retryAt = a.now().Add(retryDelay)
		} else {
			a.fatal = err
		}
		return false, err
	}
	return a.apply(page, started)
}

func (a *APISource) query() APIQuery {
	if a.cursor != "" {
		return APIQuery{File: a.opts.File, Lines: apiLines, Cursor: a.cursor}
	}
	return APIQuery{File: a.opts.File, Tail: a.opts.File == "", Lines: apiLines}
}

// apply writes a page into the mirror. A first read (or a read again after a
// refused cursor) replaces the mirror; a rotation's entries before NewFileAt
// end the old file, which the tab does not show any more, as for a local file.
func (a *APISource) apply(page APIPage, started bool) (bool, error) {
	entries := page.Entries
	rotated := started && a.mirror.Size() > 0
	if page.Rotated && page.NewFileAt != nil {
		rotated = true
		entries = entries[min(*page.NewFileAt, len(entries)):]
		if page.Gap {
			a.gaps.Add(1)
		}
	}
	if rotated {
		if err := a.mirror.reset(); err != nil {
			return false, err
		}
		a.restart = true
	}
	var b strings.Builder
	for _, e := range entries {
		b.WriteString(apiLine(e, a.opts.Bot))
	}
	if err := a.mirror.appendFrom(strings.NewReader(b.String()), int64(b.Len())); err != nil {
		return false, err
	}
	rotated, a.restart = a.restart, false
	a.cursor = page.Cursor
	// A tail read's `more` means older entries: nothing more to bring forward.
	a.more = page.More && !(started && a.opts.File == "")
	return rotated, nil
}

// Index indexes the mirror, from the start after a rotation.
func (a *APISource) Index(store *Store, rotated bool, maxBytes int64) int {
	if rotated {
		store.Clear()
	}
	return store.IndexNew(maxBytes)
}

// apiLine writes an entry back as its log wrote it, but for the padding of the
// level, which no rule reads: `date time LEVEL text` for DCS, a tab after the
// level for the bot.
func apiLine(e APIEntry, bot bool) string {
	if e.Time == "" && e.Level == "" {
		return e.Text + "\n"
	}
	sep := " "
	if bot {
		sep = "\t"
	}
	return e.Time + " " + e.Level + sep + e.Text + "\n"
}
