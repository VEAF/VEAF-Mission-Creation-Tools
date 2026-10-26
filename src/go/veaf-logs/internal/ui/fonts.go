//go:build windows

package ui

import (
	"strconv"
	"syscall"

	"github.com/tailscale/walk"
	"github.com/tailscale/win"
)

type fontKey struct {
	family       string
	size         int
	bold, italic bool
	dpi          int
}

var gdiFonts = map[fontKey]win.HFONT{}

// fontHandle is a GDI font for a walk font at a DPI, created once: walk keeps
// its own handles unexported, and the strip and the header draw with GDI.
func fontHandle(f *walk.Font, dpi int) win.HFONT {
	key := fontKey{f.Family(), f.PointSize(), f.Bold(), f.Italic(), dpi}
	if h, ok := gdiFonts[key]; ok {
		return h
	}
	lf := win.LOGFONT{LfHeight: -int32(f.PointSize() * dpi / 72), LfCharSet: win.DEFAULT_CHARSET, LfQuality: win.CLEARTYPE_QUALITY}
	if f.Bold() {
		lf.LfWeight = win.FW_BOLD
	}
	if f.Italic() {
		lf.LfItalic = 1
	}
	name, _ := syscall.UTF16FromString(f.Family())
	copy(lf.LfFaceName[:len(lf.LfFaceName)-1], name)
	h := win.CreateFontIndirect(&lf)
	gdiFonts[key] = h
	return h
}

// fontLabel is how the status bar names a font.
func fontLabel(family string, size int) string {
	return "Police : " + family + " " + strconv.Itoa(size) + " pt"
}
