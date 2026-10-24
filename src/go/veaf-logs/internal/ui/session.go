//go:build windows

package ui

import (
	"unsafe"

	"github.com/tailscale/walk"
	"github.com/tailscale/win"
	"golang.org/x/sys/windows"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
)

// restoreSession reopens the session's local tabs at once and its remote ones
// one at a time in the background, then the command line's files, which keep
// the foreground (`_restore`).
func (w *window) restoreSession() {
	if g := w.session.GoWindow; g != nil && g.Width > 200 && g.Height > 150 {
		w.mw.SetBoundsPixels(walk.Rectangle{X: g.X, Y: g.Y, Width: g.Width, Height: g.Height})
		if g.Maximized {
			win.ShowWindow(w.mw.Handle(), win.SW_MAXIMIZE)
		}
	}
	if !w.opts.Smoke {
		for position, f := range w.session.ExistingFiles() {
			if f.Remote != nil {
				w.restore.Defer(position, f)
				continue
			}
			member := ""
			if f.ArchiveMember != nil {
				member = *f.ArchiveMember
			}
			if p := w.openPath(f.Path, member); p != nil {
				w.restore.Opened(position)
				w.restored[p] = true
			}
		}
	}
	for _, p := range w.opts.Paths {
		w.openPath(p, "")
	}
	w.applyFilters()
	w.refreshStatus()
	w.reopenNextRemote()
}

// finishRestore brings the session's active tab to the front, unless another
// was chosen meanwhile (a file of the command line, one opened by the user);
// with no tab at all, the local journal by default (`_finish_restore`).
func (w *window) finishRestore() {
	front := w.current()
	chosenElsewhere := front != nil && !w.restored[front]
	if a := w.session.Active; len(w.session.Files) > 0 && a >= 0 && a < len(w.strip.Items) && !chosenElsewhere {
		w.strip.Active = a
		w.tabChanged()
	}
	if len(w.strip.Items) == 0 && len(w.opts.Paths) == 0 && !w.opts.Smoke {
		if p := currentDCSLog(); fileExists(p) {
			w.openPath(p, "")
		}
	}
}

var getWindowPlacement = windows.NewLazySystemDLL("user32.dll").NewProc("GetWindowPlacement")

type windowPlacement struct {
	length, flags, showCmd   uint32
	minPosition, maxPosition win.POINT
	normalPosition           win.RECT
}

// saveSession writes what to reopen next time; a failed save never blocks closing.
func (w *window) saveSession() {
	if w.opts.Smoke {
		return
	}
	s := w.session
	var files []logview.OpenFile
	for _, p := range w.strip.Items {
		f := logview.OpenFile{Path: p.path}
		if p.member != "" {
			member := p.member
			f.ArchiveMember = &member
		}
		if p.remote != "" {
			remote := p.remote
			f.Remote = &remote
		}
		files = append(files, f)
	}
	// Not reopened yet: they take their place back in the session's order.
	s.Files, s.Active = w.restore.Merge(files, max(0, w.strip.Active))
	s.Profile = w.currentProfile()
	s.SetFilterSet(w.filters)
	s.FontFamily, s.FontSize = w.fontFamily, w.fontSize
	s.DetailVisible = w.detailEnabled
	s.FiltersVisible = w.side.root.Visible()
	place := windowPlacement{length: uint32(unsafe.Sizeof(windowPlacement{}))}
	if ok, _, _ := getWindowPlacement.Call(uintptr(w.mw.Handle()), uintptr(unsafe.Pointer(&place))); ok != 0 {
		r := place.normalPosition
		s.GoWindow = &logview.WindowPlace{
			X: int(r.Left), Y: int(r.Top), Width: int(r.Right - r.Left), Height: int(r.Bottom - r.Top),
			Maximized: win.IsZoomed(w.mw.Handle()),
		}
	}
	_ = s.Save(logview.SessionPath())
}
