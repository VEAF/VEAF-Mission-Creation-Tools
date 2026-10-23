// logdump indexes a journal with the Go core, prints the time it took and the
// counters, and optionally writes the parity dump (one JSON record per entry).
//
//	logdump RULES.json LOG [OUT.jsonl]
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"runtime/pprof"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: logdump RULES.json LOG [OUT.jsonl]")
		os.Exit(2)
	}
	rules, err := logcore.LoadRules(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if prof := os.Getenv("LOGDUMP_CPUPROFILE"); prof != "" {
		if f, err := os.Create(prof); err == nil {
			pprof.StartCPUProfile(f)
			defer pprof.StopCPUProfile()
		}
	}
	store := logcore.NewStore(rules, logcore.NewFileBuffer(os.Args[2]))
	t0 := time.Now()
	store.IndexNew(0)
	fmt.Fprintf(os.Stderr, "entries=%d index=%.3fs\n", store.Len(), time.Since(t0).Seconds())
	if len(os.Args) > 3 {
		f, err := os.Create(os.Args[3])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		defer f.Close()
		t1 := time.Now()
		if err := logcore.DumpJSONL(store, f); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Fprintf(os.Stderr, "dump=%.3fs\n", time.Since(t1).Seconds())
		counts, _ := json.Marshal(map[string]map[string]int{
			"level": store.CountsByLevel(), "source": store.CountsBySource(), "noise": store.CountsByNoise()})
		fmt.Fprintln(os.Stderr, string(counts))
	}
}
