package logcore

import (
	"crypto/sha1"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"
)

// BigJournalCases are the filter sets timed on a real journal, the same as
// testdata/time_filters.py so the two sides can be compared line for line.
var BigJournalCases = []struct {
	Name string
	JSON string
}{
	{"diagnostic", `{"levels": {"INFO": "context", "DEBUG": "context", "TRACE": "context"}, "context_lines": 3}`},
	{"plain SCRIPTING", `{"text_filters": [{"pattern": "SCRIPTING"}]}`},
	{"regex VEAF W/E", `{"text_filters": [{"pattern": "VEAF\\|[WE]\\|", "mode": "regex"}]}`},
	{"glob + search ±2", `{"text_filters": [{"pattern": "*error*lua*", "mode": "glob"}], "search_context_lines": 2}`},
	{"inverted, case-sensitive", `{"text_filters": [{"pattern": "INFO", "case_sensitive": true, "invert": true}]}`},
}

// TestBigJournalTimings times Evaluate on the journal named by VEAF_LOGS_BIG
// and prints, per case, the time, the number of visible entries and a digest
// of them. Skipped when the variable is not set: no real journal is committed.
func TestBigJournalTimings(t *testing.T) {
	path := os.Getenv("VEAF_LOGS_BIG")
	if path == "" {
		t.Skip("VEAF_LOGS_BIG not set")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	store := NewStore(loadRules(t), &BytesBuffer{Data: data})
	store.IndexNew(0)
	fmt.Printf("%d entries\n", store.Len())
	for _, c := range BigJournalCases {
		var f FilterSet
		if err := json.Unmarshal([]byte(c.JSON), &f); err != nil {
			t.Fatal(err)
		}
		start := time.Now()
		visible, err := Evaluate(store, &f)
		elapsed := time.Since(start)
		if err != nil {
			t.Fatal(err)
		}
		if visible == nil {
			visible = []int{} // Python digests "[]", not "null"
		}
		raw, _ := json.Marshal(visible)
		fmt.Printf("%-26s %6.2f s  %7d visible  %x\n", c.Name, elapsed.Seconds(), len(visible), sha1.Sum(raw))
	}
}
