//go:build windows

package ui

import (
	"syscall"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logview"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// tabStrip draws the tabs and turns clicks into selections, closes and moves.
// Its logic — order, current tab, hit-testing — is logview.Strip, tested on its own.
type tabStrip struct {
	widget *walk.CustomWidget
	strip  *logview.Strip[*logPane]
	spans  []logview.Span
	drag   int // index of the tab being dragged, -1 when none
	hover  int

	onSelect func()
	onClose  func(i int)
}

const (
	tabStripHeight = 28 // at 96 DPI
	tabGap         = 2
	tabCloseWidth  = 14
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
	t := &tabStrip{strip: strip, drag: -1, hover: -1, widget: w}
	w.MouseDown().Attach(t.mouseDown)
	w.MouseMove().Attach(t.mouseMove)
	w.MouseUp().Attach(t.mouseUp)
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
	pad := t.scale(10)
	t.spans = logview.LayoutTabs(widths, t.scale(6), t.scale(tabGap), pad, t.scale(tabCloseWidth))
	win.SetBkMode(hdc, win.TRANSPARENT)
	top := int32(t.scale(4))
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
	return nil
}

func (t *tabStrip) mouseDown(x, _ int, button walk.MouseButton) {
	i, onClose := logview.HitTest(t.spans, x)
	if i < 0 {
		return
	}
	switch {
	case button == walk.MiddleButton || (button == walk.LeftButton && onClose):
		t.onClose(i)
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
			t.widget.Invalidate()
		}
		return
	}
	i, _ := logview.HitTest(t.spans, x)
	if i != t.hover {
		t.hover = i
		tip := ""
		if i >= 0 {
			tip = t.strip.Items[i].location
		}
		t.widget.SetToolTipText(tip)
		t.widget.Invalidate()
	}
}

func (t *tabStrip) mouseUp(int, int, walk.MouseButton) { t.drag = -1 }

// Refresh redraws the strip after the tabs changed.
func (t *tabStrip) Refresh() { t.widget.Invalidate() }

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
