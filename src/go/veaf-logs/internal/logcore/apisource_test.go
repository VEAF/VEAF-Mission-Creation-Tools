package logcore

import (
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"
)

// fakeAPI answers the queries of an APISource from a script of pages or errors.
type fakeAPI struct {
	answers []fakeAnswer
	queries []APIQuery
}

type fakeAnswer struct {
	page APIPage
	err  error
}

func (f *fakeAPI) Read(q APIQuery) (APIPage, error) {
	f.queries = append(f.queries, q)
	if len(f.answers) == 0 {
		return APIPage{Cursor: q.Cursor}, nil // nothing new
	}
	a := f.answers[0]
	f.answers = f.answers[1:]
	return a.page, a.err
}

func (f *fakeAPI) answer(p APIPage) { f.answers = append(f.answers, fakeAnswer{page: p}) }
func (f *fakeAPI) fail(err error)   { f.answers = append(f.answers, fakeAnswer{err: err}) }
func (f *fakeAPI) last() APIQuery   { return f.queries[len(f.queries)-1] }
func at(i int) *int                 { return &i }
func dcsEntry(t, text string) APIEntry {
	return APIEntry{Time: "2026-10-26 10:00:" + t, Level: "INFO", Text: text}
}
func mirrorText(src *APISource) string { return string(src.Buffer().Slice(0, src.Buffer().Size())) }
func newAPI(t *testing.T, api *fakeAPI, o APISourceOptions) (*APISource, *Store, *time.Time) {
	t.Helper()
	src, err := NewAPISource(api, o)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(src.Close)
	clock := time.Unix(1_000_000, 0)
	src.now = func() time.Time { return clock }
	return src, NewStore(loadRules(t), src.Buffer()), &clock
}

func TestAPISourceOpensWithTheTailThenFollowsTheCursor(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c1", More: true, Entries: []APIEntry{
		dcsEntry("00.100", "SCRIPTING (Main): first"),
		{Time: "2026-10-26 10:00:01.000", Level: "ERROR", Text: "SCRIPTING (Main): boom\nstack traceback:\n\t[C]: in ?"},
	}})
	src, store, _ := newAPI(t, api, APISourceOptions{})
	if err := src.Open(); err != nil {
		t.Fatal(err)
	}
	if q := api.last(); !q.Tail || q.Lines != apiLines || q.Cursor != "" || q.File != "" {
		t.Fatalf("opening query = %+v", q)
	}
	if src.Pending() {
		t.Fatal("`more` on a tail read means older entries, not newer ones")
	}
	want := "2026-10-26 10:00:00.100 INFO SCRIPTING (Main): first\n" +
		"2026-10-26 10:00:01.000 ERROR SCRIPTING (Main): boom\nstack traceback:\n\t[C]: in ?\n"
	if got := mirrorText(src); got != want {
		t.Fatalf("mirror =\n%q\nwant\n%q", got, want)
	}
	src.Index(store, false, 0)
	if store.Len() != 2 || store.Entry(1).Level != "ERROR" || len(store.Entry(1).Continuation) != 2 {
		t.Fatalf("indexed %d entries, second %+v", store.Len(), store.Entry(1))
	}

	api.answer(APIPage{Cursor: "c2", More: true, Entries: []APIEntry{dcsEntry("02.000", "SCRIPTING (Main): second")}})
	if rotated, err := src.Fetch(store.IndexedBytes()); err != nil || rotated {
		t.Fatalf("follow: rotated=%v err=%v", rotated, err)
	}
	if q := api.last(); q.Cursor != "c1" || q.Tail || q.Lines != apiLines {
		t.Fatalf("follow query = %+v", q)
	}
	if !src.Pending() {
		t.Fatal("`more` on a cursor read means newer entries: poll again at once")
	}
	src.Fetch(store.IndexedBytes())
	if api.last().Cursor != "c2" || src.Pending() {
		t.Fatalf("the next read continues from the last cursor: %+v, pending %v", api.last(), src.Pending())
	}
	src.Index(store, false, 0)
	if store.Len() != 3 {
		t.Fatalf("after follow: %d entries", store.Len())
	}
}

func TestAPISourceWritesBotLinesWithATab(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c", Entries: []APIEntry{
		{Time: "2026-10-26 10:00:00.100", Level: "WARNING", Text: "Server private1 is not responding"},
		{Text: "a line before any header"},
	}})
	src, store, _ := newAPI(t, api, APISourceOptions{Bot: true})
	src.Open()
	want := "2026-10-26 10:00:00.100 WARNING\tServer private1 is not responding\na line before any header\n"
	if got := mirrorText(src); got != want {
		t.Fatalf("mirror = %q", got)
	}
	src.Index(store, false, 0)
	if e := store.Entry(0); e.Level != "WARNING" || e.Message != "Server private1 is not responding" {
		t.Fatalf("bot entry read back as %+v", e)
	}
}

func TestAPISourceRotation(t *testing.T) {
	for _, newFileAt := range []int{0, 1} {
		t.Run(fmt.Sprint("new_file_at=", newFileAt), func(t *testing.T) {
			api := &fakeAPI{}
			api.answer(APIPage{Cursor: "c1", Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): old")}})
			src, store, _ := newAPI(t, api, APISourceOptions{})
			src.Open()
			src.Index(store, false, 0)

			entries := []APIEntry{dcsEntry("01.000", "SCRIPTING (Main): new")}
			if newFileAt == 1 {
				entries = append([]APIEntry{dcsEntry("00.500", "SCRIPTING (Main): end of old")}, entries...)
			}
			api.answer(APIPage{Cursor: "c2", Rotated: true, NewFileAt: at(newFileAt), Entries: entries})
			rotated, err := src.Fetch(store.IndexedBytes())
			if err != nil || !rotated {
				t.Fatalf("rotated=%v err=%v", rotated, err)
			}
			src.Index(store, true, 0)
			if store.Len() != 1 || store.Entry(0).Message != "new" {
				t.Fatalf("after the rotation the tab shows the new file only: %d entries, %q", store.Len(), mirrorText(src))
			}
			if src.Gaps() != 0 {
				t.Fatal("no gap was reported")
			}
		})
	}
}

func TestAPISourceRotatedWithoutNewFileYetStaysOnTheOldFile(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c1", Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): old")}})
	src, store, _ := newAPI(t, api, APISourceOptions{})
	src.Open()
	src.Index(store, false, 0)
	// The end of the old file is longer than one answer: the cursor stays on it.
	api.answer(APIPage{Cursor: "c2", Rotated: true, More: true, Entries: []APIEntry{dcsEntry("00.500", "SCRIPTING (Main): old, cont.")}})
	if rotated, _ := src.Fetch(store.IndexedBytes()); rotated {
		t.Fatal("no new file yet: not a rotation for the tab")
	}
	src.Index(store, false, 0)
	if store.Len() != 2 || !src.Pending() {
		t.Fatalf("%d entries, pending %v", store.Len(), src.Pending())
	}
}

func TestAPISourceGap(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c1", Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): old")}})
	src, store, _ := newAPI(t, api, APISourceOptions{})
	src.Open()
	src.Index(store, false, 0)
	api.answer(APIPage{Cursor: "c2", Rotated: true, Gap: true, NewFileAt: at(0), Entries: []APIEntry{dcsEntry("09.000", "SCRIPTING (Main): new")}})
	if rotated, _ := src.Fetch(store.IndexedBytes()); !rotated {
		t.Fatal("a gap is a rotation")
	}
	if src.Gaps() != 1 {
		t.Fatalf("gaps = %d", src.Gaps())
	}
}

func TestAPISourceRefusedCursorStartsOverWithATail(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c1", Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): before")}})
	src, store, _ := newAPI(t, api, APISourceOptions{})
	src.Open()
	src.Index(store, false, 0)
	api.fail(fmt.Errorf("400 Invalid cursor: %w", ErrCursorRefused))
	api.answer(APIPage{Cursor: "c9", Entries: []APIEntry{dcsEntry("05.000", "SCRIPTING (Main): after")}})
	rotated, err := src.Fetch(store.IndexedBytes())
	if err != nil || !rotated {
		t.Fatalf("rotated=%v err=%v", rotated, err)
	}
	if q := api.last(); !q.Tail || q.Cursor != "" {
		t.Fatalf("the source reads the tail again: %+v", q)
	}
	src.Index(store, true, 0)
	if store.Len() != 1 || store.Entry(0).Message != "after" {
		t.Fatalf("mirror = %q", mirrorText(src))
	}
}

func TestAPISourceTransientErrorsWaitBeforeRetrying(t *testing.T) {
	for _, cause := range []error{ErrUnavailable, ErrRemoteFileMissing} {
		t.Run(cause.Error(), func(t *testing.T) {
			api := &fakeAPI{}
			api.fail(fmt.Errorf("503: %w", cause))
			src, _, clock := newAPI(t, api, APISourceOptions{})
			if err := src.Open(); !errors.Is(err, cause) {
				t.Fatalf("err = %v", err)
			}
			if _, err := src.Fetch(0); !errors.Is(err, ErrUnavailable) || len(api.queries) != 1 {
				t.Fatalf("retried at once: %d queries, %v", len(api.queries), err)
			}
			*clock = clock.Add(retryDelay)
			api.answer(APIPage{Cursor: "c", Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): back")}})
			if _, err := src.Fetch(0); err != nil || len(api.queries) != 2 || !api.last().Tail {
				t.Fatalf("after the delay: %d queries, %v", len(api.queries), err)
			}
		})
	}
}

func TestAPISourcePermanentErrorsStopAsking(t *testing.T) {
	for _, cause := range []error{ErrAPIAuth, ErrAPIUnknownLog, ErrAPIOtherNode, errors.New("500 boom")} {
		t.Run(cause.Error(), func(t *testing.T) {
			api := &fakeAPI{}
			api.fail(fmt.Errorf("refused: %w", cause))
			src, _, clock := newAPI(t, api, APISourceOptions{})
			src.Open()
			*clock = clock.Add(time.Hour)
			if _, err := src.Fetch(0); !errors.Is(err, cause) || len(api.queries) != 1 {
				t.Fatalf("asked again: %d queries, %v", len(api.queries), err)
			}
		})
	}
}

func TestAPISourceOlderFileIsReadForwardChunkByChunk(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c1", More: true, Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): one")}})
	api.answer(APIPage{Cursor: "c2", Entries: []APIEntry{dcsEntry("01.000", "SCRIPTING (Main): two")}})
	src, store, _ := newAPI(t, api, APISourceOptions{File: "dcs-20261026-100000.log"})
	src.Open()
	if q := api.last(); q.Tail || q.File != "dcs-20261026-100000.log" || q.Cursor != "" {
		t.Fatalf("opening query = %+v", q)
	}
	if !src.Pending() {
		t.Fatal("a forward read with `more` has more to bring")
	}
	src.Fetch(0)
	if q := api.last(); q.Cursor != "c1" || q.File != "dcs-20261026-100000.log" {
		t.Fatalf("second query = %+v", q)
	}
	src.Index(store, false, 0)
	if store.Len() != 2 || src.Pending() {
		t.Fatalf("%d entries, pending %v", store.Len(), src.Pending())
	}
}

func TestAPILineKeepsWhatTheRulesRead(t *testing.T) {
	cases := map[string]struct {
		entry APIEntry
		bot   bool
		want  string
	}{
		"dcs":      {APIEntry{Time: "2026-10-26 10:00:00.100", Level: "WARNING", Text: "LOG (Main): x"}, false, "2026-10-26 10:00:00.100 WARNING LOG (Main): x\n"},
		"bot":      {APIEntry{Time: "2026-10-26 10:00:00,100", Level: "INFO", Text: "x"}, true, "2026-10-26 10:00:00,100 INFO\tx\n"},
		"headless": {APIEntry{Text: "=== Log opened UTC 2026-10-26 10:00:00"}, false, "=== Log opened UTC 2026-10-26 10:00:00\n"},
	}
	for name, c := range cases {
		if got := apiLine(c.entry, c.bot); got != c.want {
			t.Errorf("%s: %q, want %q", name, got, c.want)
		}
	}
	if strings.Contains(apiLine(APIEntry{Time: "t", Level: "INFO", Text: "a\nb"}, false), "\r") {
		t.Error("no carriage return is added")
	}
}

// A page that empties the mirror but fails to be written still restarts the index at the next one.
func TestAPISourceRotationSurvivesAFailedWrite(t *testing.T) {
	api := &fakeAPI{}
	api.answer(APIPage{Cursor: "c1", Entries: []APIEntry{dcsEntry("00.000", "SCRIPTING (Main): old")}})
	src, store, _ := newAPI(t, api, APISourceOptions{})
	src.Open()
	src.Index(store, false, 0)
	// The state a rotation leaves when its write failed: the mirror emptied, the restart owed.
	if err := src.mirror.reset(); err != nil {
		t.Fatal(err)
	}
	src.restart = true
	api.answer(APIPage{Cursor: "c2", Entries: []APIEntry{dcsEntry("01.000", "SCRIPTING (Main): new")}})
	if rotated, err := src.Fetch(store.IndexedBytes()); err != nil || !rotated {
		t.Fatalf("rotated=%v err=%v: the store must start over", rotated, err)
	}
}

func TestAPISourceWaitingSaysItIsTheServer(t *testing.T) {
	api := &fakeAPI{}
	api.fail(fmt.Errorf("503: %w", ErrUnavailable))
	src, _, _ := newAPI(t, api, APISourceOptions{})
	src.Open()
	if _, err := src.Fetch(0); err == ErrUnavailable || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v: the bare error is a local file's", err)
	}
}
