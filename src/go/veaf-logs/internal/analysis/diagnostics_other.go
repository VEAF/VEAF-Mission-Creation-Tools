//go:build !windows

package analysis

import (
	"os"
	"path/filepath"
	"runtime"
)

// machineFields: the viewer ships for Windows only; elsewhere (the Linux CI)
// the machine is named and the rest is unknown.
func machineFields(*Redactor) map[string]string {
	return map[string]string{"machine.os": runtime.GOOS + "-" + runtime.GOARCH}
}

func savedGamesDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Saved Games")
}
