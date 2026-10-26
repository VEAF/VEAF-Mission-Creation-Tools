//go:build windows

package analysis

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

var getUserDefaultLocaleName = windows.NewLazySystemDLL("kernel32.dll").NewProc("GetUserDefaultLocaleName")

// machineFields reads what the Python reads with platform.platform(),
// locale.getlocale() and shutil.disk_usage(), in the same shapes:
// `Windows-11-10.0.26300-SP0`, `fr_FR / cp1252`, `773.8 GB on D:\`.
func machineFields(r *Redactor) map[string]string {
	out := map[string]string{}
	if v := windows.RtlGetVersion(); v != nil {
		release := fmt.Sprintf("%d", v.MajorVersion)
		if v.MajorVersion == 10 && v.BuildNumber >= 22000 {
			release = "11" // what platform.release() says since Python 3.12
		}
		out["machine.os"] = fmt.Sprintf("Windows-%s-%d.%d.%d-SP%d", release, v.MajorVersion, v.MinorVersion, v.BuildNumber, v.ServicePackMajor)
	}
	language := Unknown
	buf := make([]uint16, 85) // LOCALE_NAME_MAX_LENGTH
	if n, _, _ := getUserDefaultLocaleName.Call(uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf))); n > 1 {
		language = strings.ReplaceAll(windows.UTF16ToString(buf), "-", "_")
	}
	out["machine.locale"] = fmt.Sprintf("%s / cp%d", language, windows.GetACP())
	if cwd, err := os.Getwd(); err == nil {
		anchor := filepath.VolumeName(cwd) + `\`
		var free uint64
		if p, err := windows.UTF16PtrFromString(anchor); err == nil && windows.GetDiskFreeSpaceEx(p, nil, nil, &free) == nil {
			at := r.Redact(anchor)
			if at == "" {
				at = Unknown
			}
			out["machine.free_space"] = fmt.Sprintf("%.1f GB on %s", float64(free)/(1<<30), at)
		}
	}
	return out
}

// savedGamesDir is the Saved Games known folder, wherever Windows keeps it.
func savedGamesDir() string {
	if p, err := windows.KnownFolderPath(windows.FOLDERID_SavedGames, 0); err == nil && p != "" {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Saved Games")
}
