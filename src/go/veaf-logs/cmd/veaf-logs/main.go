// veaf-logs (Go proof of concept): a viewer for DCS journals.
//
//	veaf-logs [--bench] [PATH]
//
// Without PATH it opens the journal of the DCS saved games. The window shows a
// virtualised list (the journal may hold millions of lines), colours by level
// from rules.json, a case-insensitive search, and follows the end of the file
// (tail) with rotation detection. --bench prints the time to the first frame
// and to the end of indexing on stderr, then exits.
package main

import (
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"gioui.org/app"
	"gioui.org/font"
	"gioui.org/font/gofont"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/clip"
	"gioui.org/op/paint"
	"gioui.org/text"
	"gioui.org/unit"
	"gioui.org/widget"
	"gioui.org/widget/material"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// indexSlice bounds the work done under the lock in one go, so that the window
// stays responsive while a big journal is indexed.
const indexSlice = 1 << 20

type viewer struct {
	win    *app.Window
	th     *material.Theme
	rules  *logcore.Rules
	tailer *logcore.Tailer
	path   string

	mu       sync.Mutex // guards store, view, cache, status fields
	store    *logcore.Store
	view     []int32 // nil: every entry; otherwise the entries that match the search
	filtered bool
	cache    map[int]logcore.Entry

	indexing    bool
	unavailable bool
	rotations   int
	indexStart  time.Time
	indexTook   time.Duration
	searchTook  time.Duration
	searching   bool
	searchGen   atomic.Int64

	list   widget.List
	search widget.Editor
	follow widget.Bool
	lastQ  string
}

func main() {
	bench, path, pngOut, query := false, "", "", ""
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--bench":
			bench = true
		case "--png":
			i++
			pngOut = args[i]
		case "--query":
			i++
			query = args[i]
		default:
			path = args[i]
		}
	}
	if path == "" {
		path = defaultLog()
	}
	v, err := newViewer(path)
	if err != nil {
		fatal(err)
	}

	if pngOut != "" {
		go v.poll()
		if err := v.snapshot(pngOut, query); err != nil {
			fatal(err)
		}
		return
	}
	start := time.Now()
	go func() {
		w := new(app.Window)
		w.Option(app.Title("veaf-logs (Go) — "+filepath.Base(path)), app.Size(unit.Dp(1100), unit.Dp(700)))
		v.win = w
		go v.poll()
		if err := v.run(w, bench, start); err != nil {
			fatal(err)
		}
		os.Exit(0)
	}()
	app.Main()
}

func newViewer(path string) (*viewer, error) {
	rules, err := logcore.DefaultRules()
	if err != nil {
		return nil, err
	}
	tailer, err := logcore.OpenTailer(path)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	v := &viewer{rules: rules, tailer: tailer, path: path, cache: map[int]logcore.Entry{}, indexing: true}
	v.store = logcore.NewStore(rules, tailer.Buffer)
	v.th = material.NewTheme()
	v.th.Shaper = text.NewShaper(text.WithCollection(gofont.Collection()))
	v.th.Palette = material.Palette{Fg: colText, Bg: colBackground, ContrastBg: color.NRGBA{R: 0x1f, G: 0x6f, B: 0xeb, A: 0xff}, ContrastFg: color.NRGBA{R: 0xff, G: 0xff, B: 0xff, A: 0xff}}
	v.list.Axis = layout.Vertical
	v.search.SingleLine = true
	v.follow.Value = true
	return v, nil
}

func (v *viewer) invalidate() {
	if v.win != nil {
		v.win.Invalidate()
	}
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "veaf-logs:", err)
	os.Exit(1)
}

func defaultLog() string {
	home, _ := os.UserHomeDir()
	for _, name := range []string{"DCS", "DCS.openbeta"} {
		p := filepath.Join(home, "Saved Games", name, "Logs", "dcs.log")
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return filepath.Join(home, "Saved Games", "DCS", "Logs", "dcs.log")
}

// poll indexes the file in slices, then follows it; it handles rotation.
func (v *viewer) poll() {
	v.mu.Lock()
	v.indexStart = time.Now()
	v.mu.Unlock()
	for {
		v.mu.Lock()
		from := v.store.Len()
		added, rotated, err := v.tailer.Poll(v.store, indexSlice)
		v.unavailable = err != nil
		if rotated {
			v.rotations++
			v.cache = map[int]logcore.Entry{}
			v.view, v.filtered = nil, false
			from = 0
			v.indexStart = time.Now()
			v.indexTook = 0
		}
		behind := err == nil && v.store.IndexedBytes() < v.tailer.Buffer.Size()
		finished := v.indexing && !behind
		v.indexing = behind
		if finished && v.indexTook == 0 {
			v.indexTook = time.Since(v.indexStart)
		}
		needle := v.lastQ
		v.mu.Unlock()

		if needle != "" && added > 0 && !rotated {
			v.extendSearch(needle, from)
		} else if needle != "" && rotated {
			v.startSearch(needle)
		}
		if added > 0 || rotated || err != nil || finished {
			v.invalidate()
		}
		if behind {
			// Let the window take the lock between two slices: it needs it
			// for every visible row, and a lock hogged by the indexer starves it.
			time.Sleep(time.Millisecond)
		} else {
			time.Sleep(300 * time.Millisecond)
		}
	}
}

// startSearch replaces the result with a new full search, in the background.
func (v *viewer) startSearch(needle string) {
	gen := v.searchGen.Add(1)
	if needle == "" {
		v.mu.Lock()
		v.view, v.filtered, v.searching = nil, false, false
		v.mu.Unlock()
		v.invalidate()
		return
	}
	v.mu.Lock()
	v.searching = true
	v.mu.Unlock()
	go func() {
		t0 := time.Now()
		// Search a snapshot (the index arrays only grow, a copy of their headers
		// is stable) so that the window is not blocked while the file is scanned.
		v.mu.Lock()
		snap := v.store.Snapshot()
		v.mu.Unlock()
		hits := snap.Search(needle, func() bool { return v.searchGen.Load() != gen })
		if v.searchGen.Load() != gen {
			return
		}
		v.mu.Lock()
		v.view, v.filtered, v.searching, v.searchTook = hits, true, false, time.Since(t0)
		v.cache = map[int]logcore.Entry{}
		v.mu.Unlock()
		v.invalidate()
	}()
}

// extendSearch adds the hits among the entries appended since `from`.
func (v *viewer) extendSearch(needle string, from int) {
	v.mu.Lock()
	defer v.mu.Unlock()
	if !v.filtered {
		return
	}
	v.view = append(v.view, v.store.SearchFrom(needle, from, nil)...)
}

func (v *viewer) run(w *app.Window, bench bool, start time.Time) error {
	var ops op.Ops
	first := true
	for {
		switch e := w.Event().(type) {
		case app.DestroyEvent:
			return e.Err
		case app.FrameEvent:
			gtx := app.NewContext(&ops, e)
			v.handleSearch(gtx)
			v.layout(gtx)
			e.Frame(gtx.Ops)
			if first {
				first = false
				fmt.Fprintf(os.Stderr, "first_frame=%.3fs\n", time.Since(start).Seconds())
			}
			if bench {
				v.mu.Lock()
				done := !v.indexing && v.indexTook > 0
				n := v.store.Len()
				took := v.indexTook
				v.mu.Unlock()
				if done {
					fmt.Fprintf(os.Stderr, "index_done=%.3fs (indexing alone %.3fs) entries=%d\n", time.Since(start).Seconds(), took.Seconds(), n)
					return nil
				}
			}
		}
	}
}

func (v *viewer) handleSearch(gtx layout.Context) {
	for {
		if _, ok := v.search.Update(gtx); !ok {
			break
		}
	}
	q := strings.TrimSpace(v.search.Text())
	v.mu.Lock()
	changed := q != v.lastQ
	v.lastQ = q
	v.mu.Unlock()
	if changed {
		v.startSearch(q)
	}
}

var (
	colBackground = color.NRGBA{R: 0x0d, G: 0x11, B: 0x17, A: 0xff}
	colText       = color.NRGBA{R: 0xc9, G: 0xd1, B: 0xd9, A: 0xff}
)

func (v *viewer) layout(gtx layout.Context) layout.Dimensions {
	paint.Fill(gtx.Ops, colBackground)
	return layout.Flex{Axis: layout.Vertical}.Layout(gtx,
		layout.Rigid(v.topBar),
		layout.Flexed(1, v.rows),
	)
}

func (v *viewer) topBar(gtx layout.Context) layout.Dimensions {
	return layout.UniformInset(unit.Dp(6)).Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return layout.Flex{Alignment: layout.Middle}.Layout(gtx,
			layout.Flexed(1, func(gtx layout.Context) layout.Dimensions {
				ed := material.Editor(v.th, &v.search, "Search (case-insensitive)…")
				return ed.Layout(gtx)
			}),
			layout.Rigid(layout.Spacer{Width: unit.Dp(12)}.Layout),
			layout.Rigid(material.CheckBox(v.th, &v.follow, "Follow").Layout),
			layout.Rigid(layout.Spacer{Width: unit.Dp(12)}.Layout),
			layout.Rigid(func(gtx layout.Context) layout.Dimensions {
				return material.Body2(v.th, v.status()).Layout(gtx)
			}),
		)
	})
}

func (v *viewer) status() string {
	v.mu.Lock()
	defer v.mu.Unlock()
	s := fmt.Sprintf("%d entries", v.store.Len())
	if v.filtered {
		s = fmt.Sprintf("%d of %d entries", len(v.view), v.store.Len())
		if v.searchTook > 0 {
			s += fmt.Sprintf(" (search %.0f ms)", v.searchTook.Seconds()*1000)
		}
	}
	if v.searching {
		s += " · searching…"
	}
	if v.indexing {
		total := v.tailer.Buffer.Size()
		if total > 0 {
			s += fmt.Sprintf(" · indexing %d%%", v.store.IndexedBytes()*100/total)
		}
	} else if v.indexTook > 0 && v.rotations == 0 {
		s += fmt.Sprintf(" · indexed in %.1f s", v.indexTook.Seconds())
	}
	if v.rotations > 0 {
		s += fmt.Sprintf(" · %d rotation(s)", v.rotations)
	}
	if v.unavailable {
		s += " · file unavailable"
	}
	return s
}

func (v *viewer) rows(gtx layout.Context) layout.Dimensions {
	v.mu.Lock()
	n := v.store.Len()
	if v.filtered {
		n = len(v.view)
	}
	v.mu.Unlock()
	// Gio keeps the list at the end by itself until the user scrolls up.
	v.list.ScrollToEnd = v.follow.Value
	return material.List(v.th, &v.list).Layout(gtx, n, func(gtx layout.Context, i int) layout.Dimensions {
		e, ok := v.entry(i)
		if !ok {
			return layout.Dimensions{}
		}
		return v.row(gtx, e)
	})
}

// entry decodes the entry shown at row i, through a small cache: decoding
// opens the file, which is too costly to repeat for every visible row at
// every frame.
func (v *viewer) entry(i int) (logcore.Entry, bool) {
	v.mu.Lock()
	defer v.mu.Unlock()
	idx := i
	if v.filtered {
		if i >= len(v.view) {
			return logcore.Entry{}, false
		}
		idx = int(v.view[i])
	}
	if idx >= v.store.Len() {
		return logcore.Entry{}, false
	}
	if e, ok := v.cache[idx]; ok {
		return e, true
	}
	if len(v.cache) > 4096 {
		v.cache = map[int]logcore.Entry{}
	}
	e := v.store.Entry(idx)
	v.cache[idx] = e
	return e, true
}

func (v *viewer) row(gtx layout.Context, e logcore.Entry) layout.Dimensions {
	style := v.rules.LevelStyle(e.Level)
	fg := parseColor(style.Color, color.NRGBA{R: 0xc9, G: 0xd1, B: 0xd9, A: 0xff})
	label := func(s string, c color.NRGBA, bold bool) layout.Widget {
		return func(gtx layout.Context) layout.Dimensions {
			l := material.Body2(v.th, s)
			l.Font = font.Font{Typeface: "Go Mono"}
			if bold {
				l.Font.Weight = font.Bold
			}
			l.Color = c
			l.MaxLines = 1
			return l.Layout(gtx)
		}
	}
	fixed := func(dp int, w layout.Widget) layout.FlexChild {
		return layout.Rigid(func(gtx layout.Context) layout.Dimensions {
			px := gtx.Dp(unit.Dp(dp))
			gtx.Constraints = layout.Exact(image.Pt(px, gtx.Constraints.Min.Y))
			gtx.Constraints.Min.Y = 0
			gtx.Constraints.Max.Y = 1 << 20
			return w(gtx)
		})
	}
	message := e.Message
	if n := len(e.Continuation); n > 0 {
		message += fmt.Sprintf("   [+%d lines]", n)
	}
	content := func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{Left: unit.Dp(6), Right: unit.Dp(6)}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return layout.Flex{}.Layout(gtx,
				fixed(104, label(timeOnly(e.Timestamp), color.NRGBA{R: 0x8b, G: 0x94, B: 0x9e, A: 0xff}, false)),
				fixed(80, label(e.Level, fg, style.Weight >= 600)),
				fixed(130, label(e.SourceLabel, parseColor(v.rules.SourceColor(e.Source), fg), false)),
				layout.Flexed(1, label(message, fg, false)),
			)
		})
	}
	if style.Background == "" {
		return content(gtx)
	}
	bg := parseColor(style.Background, color.NRGBA{})
	return layout.Stack{}.Layout(gtx,
		layout.Expanded(func(gtx layout.Context) layout.Dimensions {
			defer clip.Rect{Max: gtx.Constraints.Min}.Push(gtx.Ops).Pop()
			paint.Fill(gtx.Ops, bg)
			return layout.Dimensions{Size: gtx.Constraints.Min}
		}),
		layout.Stacked(content),
	)
}

func timeOnly(ts string) string {
	if len(ts) > 11 {
		return ts[11:]
	}
	return ts
}

func parseColor(hex string, fallback color.NRGBA) color.NRGBA {
	if len(hex) != 7 || hex[0] != '#' {
		return fallback
	}
	var r, g, b uint8
	if _, err := fmt.Sscanf(hex[1:], "%02x%02x%02x", &r, &g, &b); err != nil {
		return fallback
	}
	return color.NRGBA{R: r, G: g, B: b, A: 0xff}
}
