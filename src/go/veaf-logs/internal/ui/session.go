//go:build windows

package ui

import (
	"unsafe"

	"github.com/tailscale/walk"
	"github.com/tailscale/win"
	"golang.org/x/sys/windows"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
)

// restore reopens the session's tabs, then the command line's files, which
// keep the foreground; the local journal by default only when neither opened anything.
func (w *window) restore() {
	if g := w.session.GoWindow; g != nil && g.Width > 200 && g.Height > 150 {
		w.mw.SetBoundsPixels(walk.Rectangle{X: g.X, Y: g.Y, Width: g.Width, Height: g.Height})
		if g.Maximized {
			win.ShowWindow(w.mw.Handle(), win.SW_MAXIMIZE)
		}
	}
	if !w.opts.Smoke {
		for position, f := range w.session.ExistingFiles() {
			if f.Remote != nil {
				// Remote journals come back in J4; the entry is kept for the next save.
				w.pendingRemotes = append(w.pendingRemotes, pendingRemote{position: position, file: f})
				continue
			}
			member := ""
			if f.ArchiveMember != nil {
				member = *f.ArchiveMember
			}
			w.openPath(f.Path, member)
		}
		if a := w.session.Active - w.remotesBefore(w.session.Active); a >= 0 && a < len(w.strip.Items) && len(w.opts.Paths) == 0 {
			w.strip.Active = a
			w.tabChanged()
		}
	}
	for _, p := range w.opts.Paths {
		w.openPath(p, "")
	}
	if len(w.strip.Items) == 0 && len(w.opts.Paths) == 0 && !w.opts.Smoke {
		if p := currentDCSLog(); fileExists(p) {
			w.openPath(p, "")
		}
	}
	w.applyFilters()
	w.refreshStatus()
}

// remotesBefore counts the pending remote tabs placed before a session position.
func (w *window) remotesBefore(position int) int {
	n := 0
	for _, r := range w.pendingRemotes {
		if r.position < position {
			n++
		}
	}
	return n
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
	s.Files = nil
	for _, p := range w.strip.Items {
		f := logview.OpenFile{Path: p.path}
		if p.member != "" {
			member := p.member
			f.ArchiveMember = &member
		}
		s.Files = append(s.Files, f)
	}
	active := max(0, w.strip.Active)
	// Not reopened yet: they take their place back in the session's order.
	for _, r := range w.pendingRemotes {
		at := min(r.position, len(s.Files))
		s.Files = append(s.Files[:at], append([]logview.OpenFile{r.file}, s.Files[at:]...)...)
		if len(w.strip.Items) > 0 && at <= active {
			active++
		}
	}
	s.Active = active
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
