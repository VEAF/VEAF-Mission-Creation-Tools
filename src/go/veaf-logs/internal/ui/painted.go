//go:build windows

package ui

import (
	"unsafe"

	"github.com/tailscale/walk"
	. "github.com/tailscale/walk/declarative"
	"github.com/tailscale/win"
	"golang.org/x/sys/windows"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui/dark"
)

// painted is a small widget we draw ourselves and that answers a click: a
// category of the side panel, a toggle of the search bar. A walk Label keeps
// its clicks for its tooltip, and a Win32 check box writes its text in black
// whatever the dark theme, so neither would do.
type painted struct {
	widget  *walk.CustomWidget
	text    string
	color   walk.Color
	back    walk.Color // 0: the window's background
	bold    bool
	italic  bool
	center  bool
	frame   bool // a one-pixel border, as the flat push buttons (dark.FlatButton)
	hover   bool
	onClick func()
}

// declarePainted declares it in a layout; `height` and `width` are at 96 DPI, 0 for free.
func declarePainted(p *painted, width, height int) CustomWidget {
	max := Size{Width: width, Height: height}
	return CustomWidget{
		AssignTo: &p.widget, PaintMode: PaintBuffered, InvalidatesOnResize: true,
		MinSize: Size{Width: width, Height: height}, MaxSize: max,
		PaintPixels: func(c *walk.Canvas, _ walk.Rectangle) error { return p.paint(c) },
		OnMouseDown: func(_, _ int, b walk.MouseButton) {
			if b == walk.LeftButton && p.onClick != nil {
				p.onClick()
			}
		},
		OnMouseMove: func(int, int, walk.MouseButton) {
			if !p.hover {
				p.hover = true
				p.widget.Invalidate()
				trackLeave(p)
			}
		},
	}
}

func (p *painted) paint(c *walk.Canvas) error {
	hdc := c.HDC()
	b := p.widget.ClientBoundsPixels()
	r := win.RECT{Right: int32(b.Width), Bottom: int32(b.Height)}
	back := dark.Window
	if p.back != 0 {
		back = p.back
	}
	if p.hover {
		back = dark.Button
		if p.back != 0 {
			back = p.back
		}
		if p.frame && back != dark.Highlight {
			back = dark.Border
		}
	}
	if p.frame {
		win.FillRect(hdc, &r, dark.Brush(dark.Border))
		inner := win.RECT{Left: 1, Top: 1, Right: r.Right - 1, Bottom: r.Bottom - 1}
		win.FillRect(hdc, &inner, dark.Brush(back))
	} else {
		win.FillRect(hdc, &r, dark.Brush(back))
	}
	style := walk.FontStyle(0)
	if p.bold {
		style |= walk.FontBold
	}
	if p.italic {
		style |= walk.FontItalic
	}
	base := p.widget.Font()
	if f, err := walk.NewFont(base.Family(), base.PointSize(), style); err == nil {
		win.SelectObject(hdc, win.HGDIOBJ(fontHandle(f, p.widget.DPI())))
	}
	win.SetBkMode(hdc, win.TRANSPARENT)
	win.SetTextColor(hdc, win.COLORREF(p.color))
	format := uint32(win.DT_SINGLELINE | win.DT_VCENTER | win.DT_NOPREFIX | win.DT_END_ELLIPSIS)
	if p.center {
		format |= win.DT_CENTER
	} else {
		r.Left += int32(p.widget.DPI() * 2 / 96)
	}
	drawText(hdc, p.text, &r, format)
	return nil
}

// Set changes what it shows and redraws it.
func (p *painted) Set(text string, color walk.Color, bold, italic bool) {
	if p.text == text && p.color == color && p.bold == bold && p.italic == italic {
		return
	}
	p.text, p.color, p.bold, p.italic = text, color, bold, italic
	p.widget.Invalidate()
}

// SetBack changes its background (a toggle that is on).
func (p *painted) SetBack(c walk.Color) {
	if p.back != c {
		p.back = c
		p.widget.Invalidate()
	}
}

// -- hover end -------------------------------------------------------------------

var tracked = map[win.HWND]*painted{}

// trackLeave asks Windows for WM_MOUSELEAVE, to drop the hover highlight.
func trackLeave(p *painted) {
	h := p.widget.Handle()
	if _, ok := tracked[h]; !ok {
		tracked[h] = p
		dark.Subclass(h, func(hwnd win.HWND, msg uint32, _, _ uintptr) (uintptr, bool) {
			if msg == 0x02A3 { // WM_MOUSELEAVE
				if q := tracked[hwnd]; q != nil && q.hover {
					q.hover = false
					q.widget.Invalidate()
				}
			}
			return 0, false
		})
	}
	tme := win.TRACKMOUSEEVENT{CbSize: uint32(unsafe.Sizeof(win.TRACKMOUSEEVENT{})), DwFlags: win.TME_LEAVE, HwndTrack: h}
	trackMouseEvent.Call(uintptr(unsafe.Pointer(&tme)))
}

var trackMouseEvent = windows.NewLazySystemDLL("user32.dll").NewProc("TrackMouseEvent")
