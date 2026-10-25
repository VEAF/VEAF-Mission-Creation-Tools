//go:build windows

// veaf-logs: a viewer for DCS journals, the Go rewrite of the Python viewer
// (FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL, window on walk: ADR 0022).
//
//	veaf-logs [--smoke] [PATH...]
//
// Without PATH it opens the journal of the DCS saved games, if there is one.
// --smoke opens the paths, waits for their index, prints the timings and exits.
package main

//go:generate go run github.com/akavel/rsrc@v0.10.2 -arch amd64 -manifest veaf-logs.manifest -ico veaf-logs.ico -o rsrc_windows_amd64.syso

import (
	"os"
	"strings"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/ui"
)

func main() {
	opts := ui.Options{Start: time.Now()}
	for _, arg := range os.Args[1:] {
		switch {
		case arg == "--smoke":
			opts.Smoke = true
		case strings.HasPrefix(arg, "-"):
			// Unknown options are ignored, as the Python viewer does.
		default:
			opts.Paths = append(opts.Paths, arg)
		}
	}
	os.Exit(ui.Run(opts))
}
