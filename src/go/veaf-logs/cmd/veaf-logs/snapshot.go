package main

import (
	"fmt"
	"image"
	"image/png"
	"os"
	"time"

	"gioui.org/gpu/headless"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/unit"
)

// snapshot renders the window once, off screen, into a PNG: --png OUT [--query TEXT].
// It waits for the end of indexing (and of the search), then draws the list as
// the window would. It exists to check the rendering without a screen grab.
func (v *viewer) snapshot(out, query string) error {
	for {
		v.mu.Lock()
		done := !v.indexing && v.indexTook > 0
		v.mu.Unlock()
		if done {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if query != "" {
		v.search.SetText(query)
		v.mu.Lock()
		v.lastQ = query
		v.mu.Unlock()
		v.startSearch(query)
		for {
			v.mu.Lock()
			searching := v.searching
			v.mu.Unlock()
			if !searching {
				break
			}
			time.Sleep(20 * time.Millisecond)
		}
	}
	const w, h = 1100, 700
	win, err := headless.NewWindow(w, h)
	if err != nil {
		return err
	}
	defer win.Release()
	var ops op.Ops
	for frame := 0; frame < 3; frame++ { // the list settles over a few layouts
		ops.Reset()
		gtx := layout.Context{
			Ops: &ops, Now: time.Now(), Metric: unit.Metric{PxPerDp: 1, PxPerSp: 1},
			Constraints: layout.Exact(image.Pt(w, h)),
		}
		v.layout(gtx)
		if err := win.Frame(&ops); err != nil {
			return err
		}
	}
	// Scrolling cost: 300 frames moving 3 rows each, layout alone and with the GPU frame.
	v.follow.Value = false
	v.list.ScrollToEnd = false
	var lay, all time.Duration
	for frame := 0; frame < 300; frame++ {
		v.list.ScrollBy(3)
		ops.Reset()
		gtx := layout.Context{
			Ops: &ops, Now: time.Now(), Metric: unit.Metric{PxPerDp: 1, PxPerSp: 1},
			Constraints: layout.Exact(image.Pt(w, h)),
		}
		t0 := time.Now()
		v.layout(gtx)
		lay += time.Since(t0)
		if err := win.Frame(&ops); err != nil {
			return err
		}
		all += time.Since(t0)
	}
	fmt.Fprintf(os.Stderr, "scroll: layout %.2f ms/frame, layout+render %.2f ms/frame\n", float64(lay.Microseconds())/300/1000, float64(all.Microseconds())/300/1000)
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	if err := win.Screenshot(img); err != nil {
		return err
	}
	f, err := os.Create(out)
	if err != nil {
		return err
	}
	defer f.Close()
	fmt.Fprintln(os.Stderr, "status:", v.status())
	return png.Encode(f, img)
}
