package logcore

import (
	"bufio"
	"encoding/json"
	"io"
)

// DumpRecord is one line of the parity dump. The Python side (`py_dump.py`,
// `testdata/gen_golden.py`) writes the same keys.
type DumpRecord struct {
	Lineno    int      `json:"lineno"`
	Level     string   `json:"level"`
	Source    string   `json:"source"`
	Label     string   `json:"label"`
	Module    string   `json:"module"`
	Noise     []string `json:"noise"`
	Timestamp string   `json:"timestamp"`
	Subsystem string   `json:"subsystem"`
	Message   string   `json:"message"`
	Conts     int      `json:"conts"`
}

// Record builds the dump record of an entry.
func Record(e Entry) DumpRecord {
	noise := e.Noise
	if noise == nil {
		noise = []string{}
	}
	return DumpRecord{Lineno: e.Lineno, Level: e.Level, Source: e.Source, Label: e.SourceLabel,
		Module: e.Module, Noise: noise, Timestamp: e.Timestamp, Subsystem: e.Subsystem,
		Message: e.Message, Conts: len(e.Continuation)}
}

// DumpJSONL writes one JSON record per entry.
func DumpJSONL(s *Store, w io.Writer) error {
	bw := bufio.NewWriter(w)
	enc := json.NewEncoder(bw)
	enc.SetEscapeHTML(false)
	for i := 0; i < s.Len(); i++ {
		if err := enc.Encode(Record(s.Entry(i))); err != nil {
			return err
		}
	}
	return bw.Flush()
}
