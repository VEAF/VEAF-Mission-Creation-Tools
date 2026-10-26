//go:build windows

package ui

import (
	"syscall"
	"unsafe"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// tabStrip draws the tabs and turns clicks into selections, closes and moves.
// Its logic — order, current tab, hit-testing, scrolling — is logview's, tested
// on its own. Past the window's width the tabs scroll (wheel, ‹ › arrows), and
// from two tabs on a button at the left lists them (FEAT-GO-VEAF-LOGS-TABS).
type tabStrip struct {
	widget *walk.CustomWidget
	strip  *logview.Strip[*logPane]
	spans  []logview.Span // on screen, the scroll applied
	drag   int            // index of the tab being dragged, -1 when none
	hover  int

	offset          int // scroll, in pixels
	left, right     int // the tabs' visible span
	listX, arrowX   int // the list button's and the arrows' left edges, -1 when not shown
	seen, seenCount int // the current tab and the tab count at the last paint: a change brings it into view

	onSelect func()
	onClose  func(i int)
	onList   func()
	onMenu   func(i int) // right click on a tab
}

const (
	tabStripHeight = 28 // at 96 DPI
	tabGap         = 2
	tabCloseWidth  = 14
	tabButtonWidth = 24 // the list button and each arrow
)

// tabStripWidget declares the strip's widget in the window's layout; the
// strip itself is attached once the window exists.
func tabStripWidget(assign **walk.CustomWidget, t **tabStrip) CustomWidget {
	return CustomWidget{
		AssignTo: assign, PaintMode: PaintBuffered, InvalidatesOnResize: true,
		MinSize: Size{Height: tabStripHeight}, MaxSize: Size{Height: tabStripHeight},
		PaintPixels: func(c *walk.Canvas, r walk.Rectangle) error {
			if *t == nil {
				return nil
			}
			return (*t).paint(c, r)
		},
	}
}

func newTabStrip(w *walk.CustomWidget, strip *logview.Strip[*logPane]) *tabStrip {
	t := &tabStrip{strip: strip, drag: -1, hover: -1, widget: w, seen: -1, listX: -1, arrowX: -1}
	w.MouseDown().Attach(t.mouseDown)
	w.MouseMove().Attach(t.mouseMove)
	w.MouseUp().Attach(t.mouseUp)
	dark.Subclass(w.Handle(), t.wheel)
	return t
}

func (t *tabStrip) scale(v int) int { return v * t.widget.DPI() / 96 }

func (t *tabStrip) paint(c *walk.Canvas, _ walk.Rectangle) error {
	hdc := c.HDC()
	b := t.widget.ClientBoundsPixels()
	all := win.RECT{Right: int32(b.Width), Bottom: int32(b.Height)}
	win.FillRect(hdc, &all, dark.Brush(dark.Window))
	if f := t.widget.Font(); f != nil {
		win.SelectObject(hdc, win.HGDIOBJ(fontHandle(f, t.widget.DPI())))
	}
	widths := make([]int, len(t.strip.Items))
	for i, p := range t.strip.Items {
		widths[i] = textWidth(hdc, p.title)
	}
	pad, button := t.scale(10), t.scale(tabButtonWidth)
	content := logview.LayoutTabs(widths, 0, t.scale(tabGap), pad, t.scale(tabCloseWidth))
	total := logview.ContentWidth(content)

	t.left, t.right, t.listX, t.arrowX = t.scale(6), b.Width-t.scale(4), -1, -1
	if logview.ListButtonShown(len(content)) {
		t.listX = t.left
		t.left += button + t.scale(tabGap)
	}
	if total > t.right-t.left {
		t.right -= 2 * button
		t.arrowX = t.right
	}
	view := t.right - t.left
	if a := t.strip.Active; a >= 0 && a < len(content) && (a != t.seen || len(content) != t.seenCount) {
		t.offset = logview.ScrollIntoView(content[a], view, t.offset)
	}
	t.seen, t.seenCount = t.strip.Active, len(content)
	t.offset = logview.ClampOffset(total, view, t.offset)
	t.spans = content
	for i := range t.spans {
		t.spans[i].X += t.left - t.offset
		t.spans[i].CloseX += t.left - t.offset
	}

	win.SetBkMode(hdc, win.TRANSPARENT)
	top := int32(t.scale(4))
	saved := win.SaveDC(hdc)
	win.IntersectClipRect(hdc, int32(t.left), 0, int32(t.right), int32(b.Height))
	for i, s := range t.spans {
		tab := win.RECT{Left: int32(s.X), Top: top, Right: int32(s.X + s.Width), Bottom: int32(b.Height)}
		brush := dark.Brush(dark.Alternate)
		color := dark.Dim
		if i == t.strip.Active {
			brush, color = dark.Brush(dark.Border), dark.Text
		} else if i == t.hover {
			color = dark.Text
		}
		win.FillRect(hdc, &tab, brush)
		if i == t.strip.Active {
			line := win.RECT{Left: tab.Left, Top: tab.Top, Right: tab.Right, Bottom: tab.Top + int32(t.scale(2))}
			win.FillRect(hdc, &line, dark.Brush(dark.Highlight))
		}
		win.SetTextColor(hdc, win.COLORREF(color))
		label := win.RECT{Left: int32(s.X + pad), Top: top, Right: int32(s.CloseX), Bottom: int32(b.Height)}
		drawText(hdc, t.strip.Items[i].title, &label, win.DT_LEFT|win.DT_SINGLELINE|win.DT_VCENTER|win.DT_NOPREFIX)
		closeBox := win.RECT{Left: int32(s.CloseX), Top: top, Right: int32(s.CloseX + s.CloseWidth), Bottom: int32(b.Height)}
		drawText(hdc, "×", &closeBox, win.DT_CENTER|win.DT_SINGLELINE|win.DT_VCENTER)
	}
	win.RestoreDC(hdc, saved)

	if t.listX >= 0 {
		t.drawButton(hdc, t.listX, top, b.Height, "≡", true)
	}
	if t.arrowX >= 0 {
		t.drawButton(hdc, t.arrowX, top, b.Height, "‹", t.offset > 0)
		t.drawButton(hdc, t.arrowX+button, top, b.Height, "›", t.offset < total-view)
	}
	return nil
}

func (t *tabStrip) drawButton(hdc win.HDC, x int, top int32, height int, text string, enabled bool) {
	r := win.RECT{Left: int32(x), Top: top, Right: int32(x + t.scale(tabButtonWidth)), Bottom: int32(height)}
	win.FillRect(hdc, &r, dark.Brush(dark.Alternate))
	color := dark.Text
	if !enabled {
		color = dark.Dim
	}
	win.SetTextColor(hdc, win.COLORREF(color))
	drawText(hdc, text, &r, win.DT_CENTER|win.DT_SINGLELINE|win.DT_VCENTER)
}

// scroll moves the strip by dx pixels; the next paint keeps it within the tabs.
func (t *tabStrip) scroll(dx int) {
	t.offset += dx
	t.widget.Invalidate()
}

// wheel scrolls the strip with the mouse wheel, either of them.
func (t *tabStrip) wheel(_ win.HWND, msg uint32, wp, _ uintptr) (uintptr, bool) {
	const wmMouseHWheel = 0x020E
	if msg != win.WM_MOUSEWHEEL && msg != wmMouseHWheel {
		return 0, false
	}
	steps := int(int16(wp>>16)) / 120
	if msg == win.WM_MOUSEWHEEL {
		steps = -steps // wheel down: further right
	}
	t.scroll(steps * t.scale(60))
	return 0, true
}

func (t *tabStrip) mouseDown(x, _ int, button walk.MouseButton) {
	width := t.scale(tabButtonWidth)
	switch {
	case t.listX >= 0 && x >= t.listX && x < t.listX+width:
		t.onList()
		return
	case t.arrowX >= 0 && x >= t.arrowX && x < t.arrowX+width:
		t.scroll(-(t.right - t.left) / 2)
		return
	case t.arrowX >= 0 && x >= t.arrowX+width:
		t.scroll((t.right - t.left) / 2)
		return
	case x < t.left || x >= t.right:
		return
	}
	i, onClose := logview.HitTest(t.spans, x)
	if i < 0 {
		return
	}
	switch {
	case button == walk.MiddleButton || (button == walk.LeftButton && onClose):
		t.onClose(i)
	case button == walk.RightButton:
		t.onMenu(i)
	case button == walk.LeftButton:
		if i != t.strip.Active {
			t.strip.Active = i
			t.onSelect()
		}
		t.drag = i
		t.widget.Invalidate()
	}
}

func (t *tabStrip) mouseMove(x, _ int, _ walk.MouseButton) {
	if t.drag >= 0 {
		if to := logview.DropIndex(t.spans, x); to >= 0 && to != t.drag {
			t.strip.Move(t.drag, to)
			t.drag = to
			t.seen = to // dragged, not chosen: the strip does not jump under the mouse
			t.widget.Invalidate()
		}
		return
	}
	i := -1
	if x >= t.left && x < t.right {
		i, _ = logview.HitTest(t.spans, x)
	}
	if i != t.hover {
		t.hover = i
		tip := ""
		switch {
		case i >= 0:
			tip = t.strip.Items[i].location
		case t.listX >= 0 && x >= t.listX && x < t.listX+t.scale(tabButtonWidth):
			tip = "Tous les onglets"
		}
		t.widget.SetToolTipText(tip)
		t.widget.Invalidate()
	}
}

func (t *tabStrip) mouseUp(int, int, walk.MouseButton) { t.drag = -1 }

// Refresh redraws the strip after the tabs changed.
func (t *tabStrip) Refresh() { t.widget.Invalidate() }

// popupMenu shows a menu of items at the mouse and returns the one chosen;
// `checked` gets a check mark (-1: none).
func popupMenu(owner win.HWND, items []string, checked int) (int, bool) {
	menu := win.CreatePopupMenu()
	defer win.DestroyMenu(menu)
	for i, text := range items {
		u, _ := syscall.UTF16PtrFromString(text)
		mii := win.MENUITEMINFO{FMask: win.MIIM_ID | win.MIIM_STRING | win.MIIM_STATE, WID: uint32(i + 1), DwTypeData: u}
		mii.CbSize = uint32(unsafe.Sizeof(mii))
		if i == checked {
			mii.FState = win.MFS_CHECKED
		}
		win.InsertMenuItem(menu, uint32(i), true, &mii)
	}
	var at win.POINT
	win.GetCursorPos(&at)
	id := win.TrackPopupMenu(menu, win.TPM_RETURNCMD|win.TPM_LEFTALIGN|win.TPM_TOPALIGN, at.X, at.Y, 0, owner, nil)
	return int(id) - 1, id != 0
}

// -- GDI text helpers ---------------------------------------------------------------

func textWidth(hdc win.HDC, s string) int {
	u, _ := syscall.UTF16FromString(s)
	if len(u) <= 1 {
		return 0
	}
	var size win.SIZE
	win.GetTextExtentPoint32(hdc, &u[0], int32(len(u)-1), &size)
	return int(size.CX)
}

func drawText(hdc win.HDC, s string, r *win.RECT, format uint32) {
	u, _ := syscall.UTF16PtrFromString(s)
	win.DrawTextEx(hdc, u, -1, r, format, nil)
}
