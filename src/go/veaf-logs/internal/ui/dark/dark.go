//go:build windows

// Package dark gives Win32 controls the dark theme of the Python viewer (ADR 0022).
//
// Part of it rests on undocumented Windows entry points — uxtheme's ordinals
// 104, 133, 135, 136 and the UAH menu-bar messages, the technique of the
// win32-darkmode samples. Each is looked up at run time and skipped when
// absent: a Windows that drops one shows the light theme, it does not fail.
package dark

import (
	"syscall"
	"unsafe"

	"github.com/tailscale/walk"
	"github.com/tailscale/win"
	"golang.org/x/sys/windows"
)

// The palette of the Python viewer (ui/main_window.py, _apply_dark_palette).
var (
	Window    = walk.RGB(0x0d, 0x11, 0x17)
	Alternate = walk.RGB(0x16, 0x1b, 0x22)
	Button    = walk.RGB(0x21, 0x26, 0x2d)
	Text      = walk.RGB(0xc9, 0xd1, 0xd9)
	Highlight = walk.RGB(0x1f, 0x6f, 0xeb)
	Border    = walk.RGB(0x30, 0x36, 0x3d)
	Dim       = walk.RGB(0x8b, 0x94, 0x9e)
)

var (
	user32   = windows.NewLazySystemDLL("user32.dll")
	uxtheme  = windows.NewLazySystemDLL("uxtheme.dll")
	comctl32 = windows.NewLazySystemDLL("comctl32.dll")
	gdi32    = windows.NewLazySystemDLL("gdi32.dll")
	dwmapi   = windows.NewLazySystemDLL("dwmapi.dll")

	setWindowTheme    = uxtheme.NewProc("SetWindowTheme")
	setWindowSubclass = comctl32.NewProc("SetWindowSubclass")
	defSubclassProc   = comctl32.NewProc("DefSubclassProc")
	getMenuBarInfo    = user32.NewProc("GetMenuBarInfo")
	getMenuStringW    = user32.NewProc("GetMenuStringW")
	mapWindowPoints   = user32.NewProc("MapWindowPoints")
	getWindowDC       = user32.NewProc("GetWindowDC")
	enumChildWindows  = user32.NewProc("EnumChildWindows")
	getClassNameW     = user32.NewProc("GetClassNameW")
	createSolidBrush  = gdi32.NewProc("CreateSolidBrush")
	dwmSetAttribute   = dwmapi.NewProc("DwmSetWindowAttribute")

	allowDarkModeForWindow uintptr
)

// Brush returns a GDI brush of a colour, created once and kept for the process.
func Brush(c walk.Color) win.HBRUSH {
	if b, ok := brushes[c]; ok {
		return b
	}
	h, _, _ := createSolidBrush.Call(uintptr(c))
	brushes[c] = win.HBRUSH(h)
	return win.HBRUSH(h)
}

var brushes = map[walk.Color]win.HBRUSH{}

// WalkBrush is a walk brush of a colour, for the widgets' backgrounds.
func WalkBrush(c walk.Color) walk.Brush {
	if b, ok := walkBrushes[c]; ok {
		return b
	}
	b, _ := walk.NewSolidColorBrush(c)
	walkBrushes[c] = b
	return b
}

var walkBrushes = map[walk.Color]walk.Brush{}

// Init sets the application's dark mode. It must run before any window is
// created: the app mode decides how menus are made.
func Init() {
	h, err := windows.LoadLibrary("uxtheme.dll")
	if err != nil {
		return
	}
	ordinal := func(n uintptr) uintptr { p, _ := windows.GetProcAddressByOrdinal(h, n); return p }
	if p := ordinal(135); p != 0 {
		syscall.SyscallN(p, 2) // SetPreferredAppMode(ForceDark)
	}
	allowDarkModeForWindow = ordinal(133)
	if p := ordinal(104); p != 0 {
		syscall.SyscallN(p) // RefreshImmersiveColorPolicyState
	}
	if p := ordinal(136); p != 0 {
		syscall.SyscallN(p) // FlushMenuThemes: menus follow the app mode
	}
}

// Theme gives a control a dark visual style ("DarkMode_Explorer" for scroll
// bars and buttons, "DarkMode_CFD" for edit fields and combo boxes).
func Theme(hwnd win.HWND, name string) {
	if allowDarkModeForWindow != 0 {
		syscall.SyscallN(allowDarkModeForWindow, uintptr(hwnd), 1)
	}
	p, _ := syscall.UTF16PtrFromString(name)
	setWindowTheme.Call(uintptr(hwnd), uintptr(unsafe.Pointer(p)), 0)
}

// NoTheme removes a control's visual style, for those that have no dark one
// and take colours only without it (the progress bar).
func NoTheme(hwnd win.HWND) {
	empty, _ := syscall.UTF16PtrFromString("")
	setWindowTheme.Call(uintptr(hwnd), uintptr(unsafe.Pointer(empty)), uintptr(unsafe.Pointer(empty)))
}

// NoEdge removes a control's sunken client edge, drawn light whatever the theme.
func NoEdge(hwnd win.HWND) {
	ex := win.GetWindowLong(hwnd, win.GWL_EXSTYLE)
	win.SetWindowLong(hwnd, win.GWL_EXSTYLE, ex&^win.WS_EX_CLIENTEDGE)
	style := win.GetWindowLong(hwnd, win.GWL_STYLE)
	win.SetWindowLong(hwnd, win.GWL_STYLE, style&^win.WS_BORDER)
	win.SetWindowPos(hwnd, 0, 0, 0, 0, 0, win.SWP_FRAMECHANGED|win.SWP_NOMOVE|win.SWP_NOSIZE|win.SWP_NOZORDER|win.SWP_NOACTIVATE)
}

// TitleBar asks the window manager for a dark title bar.
func TitleBar(hwnd win.HWND) {
	on := int32(1)
	dwmSetAttribute.Call(uintptr(hwnd), 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, uintptr(unsafe.Pointer(&on)), 4)
}

// -- subclassing -------------------------------------------------------------
//
// One callback for every subclassed window: syscall.NewCallback never frees
// what it creates and caps how many it creates.

// Proc handles a message; it returns false to let the window's own procedure have it.
type Proc func(hwnd win.HWND, msg uint32, wp, lp uintptr) (result uintptr, handled bool)

var (
	procs    = map[win.HWND][]Proc{}
	callback = syscall.NewCallback(func(hwnd win.HWND, msg uint32, wp, lp, _, _ uintptr) uintptr {
		for _, p := range procs[hwnd] {
			if r, done := p(hwnd, msg, wp, lp); done {
				return r
			}
		}
		if msg == win.WM_NCDESTROY {
			delete(procs, hwnd)
		}
		r, _, _ := defSubclassProc.Call(uintptr(hwnd), uintptr(msg), wp, lp)
		return r
	})
)

// Subclass adds a message handler to a window, before its own procedure.
func Subclass(hwnd win.HWND, p Proc) {
	if _, ok := procs[hwnd]; !ok {
		setWindowSubclass.Call(uintptr(hwnd), callback, 1, 0)
	}
	procs[hwnd] = append(procs[hwnd], p)
}

// Default calls the window's own procedure, from inside a Proc.
func Default(hwnd win.HWND, msg uint32, wp, lp uintptr) uintptr {
	r, _, _ := defSubclassProc.Call(uintptr(hwnd), uintptr(msg), wp, lp)
	return r
}

// ClassName is a window's class.
func ClassName(hwnd win.HWND) string {
	var buf [64]uint16
	getClassNameW.Call(uintptr(hwnd), uintptr(unsafe.Pointer(&buf[0])), 64)
	return syscall.UTF16ToString(buf[:])
}

var (
	enumFound    []win.HWND
	enumCallback = syscall.NewCallback(func(h win.HWND, _ uintptr) uintptr { enumFound = append(enumFound, h); return 1 })
)

// Children lists every descendant window (UI thread only).
func Children(parent win.HWND) []win.HWND {
	enumFound = nil
	enumChildWindows.Call(uintptr(parent), enumCallback, 0)
	return append([]win.HWND(nil), enumFound...)
}

// -- the menu bar, painted on the UAH messages --------------------------------

const (
	wmUAHDrawMenu     = 0x0091
	wmUAHDrawMenuItem = 0x0092
	objidMenu         = 0xFFFFFFFD
)

type menuBarInfo struct {
	cbSize  uint32
	rcBar   win.RECT
	hMenu   win.HMENU
	hwndMnu win.HWND
	flags   int32
}

type uahMenu struct {
	hmenu win.HMENU
	hdc   win.HDC
	flags uint32
}

type drawItem struct {
	ctlType, ctlID, itemID, itemAction, itemState uint32
	hwndItem                                      win.HWND
	hdc                                           win.HDC
	rcItem                                        win.RECT
	itemData                                      uintptr
}

type uahDrawMenuItem struct {
	dis      drawItem
	um       uahMenu
	position int32
}

func menuBarRect(hwnd win.HWND) (win.RECT, bool) {
	mbi := menuBarInfo{cbSize: uint32(unsafe.Sizeof(menuBarInfo{}))}
	if ok, _, _ := getMenuBarInfo.Call(uintptr(hwnd), objidMenu, 0, uintptr(unsafe.Pointer(&mbi))); ok == 0 {
		return win.RECT{}, false
	}
	var w win.RECT
	win.GetWindowRect(hwnd, &w)
	r := mbi.rcBar
	r.Left, r.Right, r.Top, r.Bottom = r.Left-w.Left, r.Right-w.Left, r.Top-w.Top, r.Bottom-w.Top
	return r, true
}

// paintMenuLine covers the one-pixel light line Windows draws under a menu bar.
func paintMenuLine(hwnd win.HWND) {
	var client, w win.RECT
	win.GetClientRect(hwnd, &client)
	mapWindowPoints.Call(uintptr(hwnd), 0, uintptr(unsafe.Pointer(&client)), 2)
	win.GetWindowRect(hwnd, &w)
	line := win.RECT{Left: client.Left - w.Left, Right: client.Right - w.Left, Top: client.Top - w.Top - 1, Bottom: client.Top - w.Top}
	raw, _, _ := getWindowDC.Call(uintptr(hwnd))
	hdc := win.HDC(raw)
	win.FillRect(hdc, &line, Brush(Alternate))
	win.ReleaseDC(hwnd, hdc)
}

// MenuBar paints a main window's menu bar dark.
func MenuBar(hwnd win.HWND) {
	Subclass(hwnd, func(hwnd win.HWND, msg uint32, wp, lp uintptr) (uintptr, bool) {
		switch msg {
		case wmUAHDrawMenu:
			m := *(**uahMenu)(unsafe.Pointer(&lp)) // lParam points to the structure
			if r, ok := menuBarRect(hwnd); ok {
				win.FillRect(m.hdc, &r, Brush(Alternate))
			}
			return 1, true
		case wmUAHDrawMenuItem:
			it := *(**uahDrawMenuItem)(unsafe.Pointer(&lp))
			var label [256]uint16
			getMenuStringW.Call(uintptr(it.um.hmenu), uintptr(it.position), uintptr(unsafe.Pointer(&label[0])), 256, 0x400 /* MF_BYPOSITION */)
			brush := Brush(Alternate)
			if it.dis.itemState&(0x40|0x1|0x80) != 0 { // hot, selected, pushed
				brush = Brush(Border)
			}
			win.FillRect(it.um.hdc, &it.dis.rcItem, brush)
			flags := uint32(win.DT_CENTER | win.DT_SINGLELINE | win.DT_VCENTER)
			if it.dis.itemState&0x100 != 0 { // ODS_NOACCEL: the mnemonic is underlined once Alt is pressed
				flags |= 0x100000 // DT_HIDEPREFIX
			}
			win.SetBkMode(it.um.hdc, win.TRANSPARENT)
			win.SetTextColor(it.um.hdc, win.COLORREF(Text))
			win.DrawTextEx(it.um.hdc, &label[0], -1, &it.dis.rcItem, flags, nil)
			return 1, true
		case win.WM_NCPAINT, win.WM_NCACTIVATE:
			r := Default(hwnd, msg, wp, lp)
			paintMenuLine(hwnd)
			return r, true
		}
		return 0, false
	})
	win.DrawMenuBar(hwnd)
}

// -- the table -------------------------------------------------------------------

// Table darkens a walk TableView: its list views (background past the last
// column, scroll bars) and their headers, which are painted here — their
// themes keep their own text colour, and their custom-draw notifications
// never reached a subclass of the list view (counted 0 in the spike).
func Table(tableView win.HWND, font func() win.HFONT) {
	for _, h := range Children(tableView) {
		switch ClassName(h) {
		case "SysListView32":
			Theme(h, "DarkMode_Explorer")
			win.SendMessage(h, 0x1001 /* LVM_SETBKCOLOR */, 0, uintptr(Window))
		case "SysHeader32":
			Subclass(h, headerProc(font))
		}
	}
}

func headerProc(font func() win.HFONT) Proc {
	return func(hwnd win.HWND, msg uint32, wp, lp uintptr) (uintptr, bool) {
		switch msg {
		case win.WM_ERASEBKGND:
			return 1, true
		case win.WM_PAINT:
			var ps win.PAINTSTRUCT
			hdc := win.BeginPaint(hwnd, &ps)
			var client win.RECT
			win.GetClientRect(hwnd, &client)
			win.FillRect(hdc, &client, Brush(Alternate))
			f := win.HFONT(win.SendMessage(hwnd, win.WM_GETFONT, 0, 0)) // the header's own UI font
			if font != nil {
				f = font()
			}
			if f != 0 {
				win.SelectObject(hdc, win.HGDIOBJ(f))
			}
			win.SetBkMode(hdc, win.TRANSPARENT)
			win.SetTextColor(hdc, win.COLORREF(Text))
			n := int(win.SendMessage(hwnd, win.HDM_GETITEMCOUNT, 0, 0))
			for i := 0; i < n; i++ {
				var r win.RECT
				win.SendMessage(hwnd, win.HDM_GETITEMRECT, uintptr(i), uintptr(unsafe.Pointer(&r)))
				var text [128]uint16
				item := win.HDITEM{Mask: win.HDI_TEXT, PszText: &text[0], CchTextMax: 128}
				win.SendMessage(hwnd, win.HDM_GETITEM, uintptr(i), uintptr(unsafe.Pointer(&item)))
				label := r
				label.Left += 6
				win.DrawTextEx(hdc, &text[0], -1, &label, win.DT_LEFT|win.DT_SINGLELINE|win.DT_VCENTER|win.DT_END_ELLIPSIS, nil)
				sep := win.RECT{Left: r.Right - 1, Top: r.Top + 4, Right: r.Right, Bottom: r.Bottom - 4}
				win.FillRect(hdc, &sep, Brush(Border))
			}
			win.EndPaint(hwnd, &ps)
			return 0, true
		}
		return 0, false
	}
}

// -- other controls ------------------------------------------------------------------

// ListColors answers WM_CTLCOLORLISTBOX for a window: a combo box (its
// drop-down list asks through it) or a dialog holding a list box.
func ListColors(hwnd win.HWND) {
	Subclass(hwnd, func(_ win.HWND, msg uint32, wp, _ uintptr) (uintptr, bool) {
		if msg == 0x0134 { // WM_CTLCOLORLISTBOX
			win.SetTextColor(win.HDC(wp), win.COLORREF(Text))
			win.SetBkColor(win.HDC(wp), win.COLORREF(Alternate))
			return uintptr(Brush(Alternate)), true
		}
		return 0, false
	})
}

// ProgressBar colours a progress bar, which has no dark visual style.
func ProgressBar(hwnd win.HWND) {
	NoTheme(hwnd)
	win.SendMessage(hwnd, 0x409 /* PBM_SETBARCOLOR */, 0, uintptr(Highlight))
	win.SendMessage(hwnd, 0x2001 /* PBM_SETBKCOLOR */, 0, uintptr(Alternate))
}
