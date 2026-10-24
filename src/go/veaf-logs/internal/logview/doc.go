package logview

import (
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// indexSlice bounds the work done under the lock in one go, so the window can
// take it between two slices while a big journal is indexed.
const indexSlice = 1 << 20

// cacheSize is how many decoded entries are kept: the table asks for every
// cell of a row separately, and decoding reads the file.
const cacheSize = 4096

// Doc is what one tab shows: a journal, its index, the rows the filters keep.
// The poll goroutine indexes and follows it; the window reads it under the same lock.
type Doc struct {
	Rules      *logcore.Rules
	Followable bool

	src   logcore.Follower
	stop  chan struct{}
	once  sync.Once
	dirty atomic.Bool

	mu          sync.Mutex
	store       *logcore.Store
	filters     logcore.FilterSet
	visible     []int // nil: every entry
	cache       map[int]logcore.Entry
	indexing    bool
	running     bool // a poll goroutine is at work; false once it decided to stop
	cancelled   bool
	unavailable bool
	rotations   int
	resets      int // rows replaced rather than appended: rotation, new filters, refilter
}

// NewDoc prepares the document of a journal; Start begins indexing it.
func NewDoc(rules *logcore.Rules, src logcore.Follower, followable bool) *Doc {
	return &Doc{
		Rules: rules, Followable: followable, src: src, stop: make(chan struct{}),
		store: logcore.NewStore(rules, src.Buffer()), filters: logcore.NewFilterSet(),
		cache: map[int]logcore.Entry{}, indexing: true,
	}
}

// Start indexes the journal in the background, then follows it if it can be followed.
func (d *Doc) Start() {
	d.mu.Lock()
	d.running = true
	d.mu.Unlock()
	go d.poll()
}

// Close stops the polling and releases the source (connection, mirror file).
func (d *Doc) Close() {
	d.once.Do(func() {
		close(d.stop)
		d.src.Close()
	})
}

// Dirty tells, once, that rows or status changed since the last call.
func (d *Doc) Dirty() bool { return d.dirty.Swap(false) }

func (d *Doc) sleep(delay time.Duration) bool {
	select {
	case <-d.stop:
		return false
	case <-time.After(delay):
		return true
	}
}

func (d *Doc) poll() {
	for {
		select {
		case <-d.stop:
			return
		default:
		}
		// The network (Fetch) must not hold the lock the window needs for every row.
		d.mu.Lock()
		indexed := d.store.IndexedBytes()
		d.mu.Unlock()
		rotated, err := d.src.Fetch(indexed)

		d.mu.Lock()
		if d.cancelled {
			d.indexing = false
			d.running = false
			d.mu.Unlock()
			d.dirty.Store(true)
			return
		}
		d.unavailable = err != nil
		if err != nil {
			rotated = false
		}
		last := d.store.Len() - 1
		if rotated {
			d.rotations++
			d.resets++
			d.cache = map[int]logcore.Entry{}
			last = -1
		}
		before := d.store.IndexedBytes()
		if rotated {
			before = 0
		}
		if err == nil {
			d.src.Index(d.store, rotated, indexSlice)
		}
		// Growth is measured in bytes, not in entries: lines with no header join
		// the last entry without adding one, and a stack trace that arrives after
		// its error line must still reach the row already shown. (The Python
		// viewer stops at `if not added`, so such a trace waits for another repaint.)
		grew := d.store.IndexedBytes() > before
		if grew && last >= 0 {
			delete(d.cache, last)
		}
		if grew || rotated {
			d.refilter()
		}
		// Behind only while a slice still makes progress: an incomplete last line
		// stays unindexed until its newline, and is no reason to poll in a loop.
		behind := err == nil && ((grew && d.store.IndexedBytes() < d.src.Buffer().Size()) || d.src.Pending())
		changed := grew || rotated || err != nil || d.indexing != behind
		d.indexing = behind
		if !behind && !d.Followable {
			// Decided under the lock, so that Reclassify knows it must start another.
			d.running = false
		}
		d.mu.Unlock()
		if changed {
			d.dirty.Store(true)
		}

		switch {
		case behind:
			// Let the window take the lock between two slices.
			if !d.sleep(time.Millisecond) {
				return
			}
		case !d.Followable:
			return // an archive is a snapshot: nothing will be added
		default:
			if !d.sleep(d.src.PollInterval()) {
				return
			}
		}
	}
}

// refilter recomputes the visible rows; the caller holds the lock.
func (d *Doc) refilter() {
	if d.filters.IsEmpty() {
		if d.visible != nil {
			d.resets++ // the filters were just removed: every row comes back
		}
		d.visible = nil
		return
	}
	visible, err := logcore.Evaluate(d.store, &d.filters)
	if err != nil {
		return // an invalid pattern never reaches here: the window validates it first
	}
	if visible == nil {
		visible = []int{}
	}
	d.visible = visible
	d.resets++
}

// SetFilters applies a filter set; an invalid pattern is returned and nothing changes.
func (d *Doc) SetFilters(f logcore.FilterSet) error {
	for _, t := range f.TextFilters {
		if _, err := logcore.CompilePattern(t.Pattern, t.Mode, t.CaseSensitive); err != nil {
			return err
		}
	}
	d.mu.Lock()
	d.filters = f.Copy()
	d.refilter()
	d.mu.Unlock()
	d.dirty.Store(true)
	return nil
}

// Reclassify indexes the journal again with a new catalogue (`LogStore.reclassify`,
// the Règles menu's F5); the filters in force apply to the new index. The
// Python indexes it whole on the window's thread; here the poll goroutine does,
// in slices, and one is started again when the previous one was over (an
// archive, an interrupted indexing, which this resumes to the end).
func (d *Doc) Reclassify(rules *logcore.Rules) {
	d.mu.Lock()
	d.Rules = rules
	d.store = logcore.NewStore(rules, d.src.Buffer())
	d.cache = map[int]logcore.Entry{}
	d.cancelled = false
	d.indexing = true
	d.resets++
	d.refilter()
	restart := !d.running
	d.running = true
	d.mu.Unlock()
	d.dirty.Store(true)
	if restart {
		go d.poll()
	}
}

// Filters is the filter set in force.
func (d *Doc) Filters() logcore.FilterSet {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.filters.Copy()
}

// Cancel interrupts the indexing: what is indexed stays shown, and the tab
// stops following — the index is sequential, it cannot skip what was not read.
//
// The Python viewer resumes at its next poll (`LogTab.poll` calls an unbounded
// `index_new()` once the indexer stopped), which makes the button a pause of a
// fraction of a second; here it does what it says.
func (d *Doc) Cancel() {
	d.mu.Lock()
	d.cancelled = true
	d.mu.Unlock()
	d.dirty.Store(true)
}

// Rows is the number of rows shown.
func (d *Doc) Rows() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.visible != nil {
		return len(d.visible)
	}
	return d.store.Len()
}

func (d *Doc) indexOf(row int) int {
	if d.visible != nil {
		if row < 0 || row >= len(d.visible) {
			return -1
		}
		return d.visible[row]
	}
	if row < 0 || row >= d.store.Len() {
		return -1
	}
	return row
}

// Entry decodes the entry shown at a row.
func (d *Doc) Entry(row int) (logcore.Entry, bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.entryLocked(row)
}

func (d *Doc) entryLocked(row int) (logcore.Entry, bool) {
	idx := d.indexOf(row)
	if idx < 0 {
		return logcore.Entry{}, false
	}
	if e, ok := d.cache[idx]; ok {
		return e, true
	}
	if len(d.cache) >= cacheSize {
		d.cache = map[int]logcore.Entry{}
	}
	e := d.store.Entry(idx)
	d.cache[idx] = e
	return e, true
}

// Entries decodes the entries shown at the given rows, in order.
func (d *Doc) Entries(rows []int) []logcore.Entry {
	d.mu.Lock()
	defer d.mu.Unlock()
	out := make([]logcore.Entry, 0, len(rows))
	for _, r := range rows {
		if e, ok := d.entryLocked(r); ok {
			out = append(out, e)
		}
	}
	return out
}

// Resets counts the times the rows were replaced rather than appended (a
// rotation, new filters): the table then reloads instead of appending.
func (d *Doc) Resets() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.resets
}

// Counts are the side panel's counters for this journal.
type Counts struct {
	Levels      map[string]int
	Sources     map[string]int
	SourceOrder []string // first appearance: breaks ties between equal counts
	Noise       map[string]int
}

// Counts reads the counters per level, source and noise family.
func (d *Doc) Counts() Counts {
	d.mu.Lock()
	defer d.mu.Unlock()
	return Counts{Levels: d.store.CountsByLevel(), Sources: d.store.CountsBySource(), SourceOrder: d.store.SourceOrder(), Noise: d.store.CountsByNoise()}
}

// MaxMessageLength is the longest message seen, in bytes: it sizes the message column.
func (d *Doc) MaxMessageLength() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.store.MaxMessageLength()
}

// Status is what the status bar and the progress bar show.
type Status struct {
	Total, Shown  int
	Indexing      bool
	Indexed, Size int64
	Cancelled     bool
	Unavailable   bool
	Rotations     int
}

// Status reads the document's state.
func (d *Doc) Status() Status {
	d.mu.Lock()
	defer d.mu.Unlock()
	s := Status{
		Total: d.store.Len(), Indexing: d.indexing, Indexed: d.store.IndexedBytes(), Size: d.src.Buffer().Size(),
		Cancelled: d.cancelled, Unavailable: d.unavailable, Rotations: d.rotations,
	}
	s.Shown = s.Total
	if d.visible != nil {
		s.Shown = len(d.visible)
	}
	return s
}

// Percent is the indexing progress, 0 to 100.
func (s Status) Percent() int {
	if s.Size <= 0 {
		return 100
	}
	return int(s.Indexed * 100 / s.Size)
}

// CountsText is the left part of the status bar.
func (s Status) CountsText() string {
	text := fmt.Sprintf("%d lignes affichées sur %d", s.Shown, s.Total)
	if hidden := s.Total - s.Shown; hidden > 0 {
		text += fmt.Sprintf("   —   %d masquées par les filtres", hidden)
	}
	return text
}

// FollowText is the right part of the status bar.
func FollowText(followable, follow bool, s Status) string {
	switch {
	case !followable:
		return "archive (pas de suivi)"
	case s.Cancelled:
		return "indexation interrompue (pas de suivi)"
	case follow:
		return "suivi actif"
	}
	return "suivi en pause"
}

// NoTabText is the status bar without any tab.
const NoTabText = "Aucun journal ouvert."
