package analysis

import (
	"strings"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// A search the user typed reaches the excerpt's header, which the online layer
// sends as it stands: it is redacted like the records.
func TestTypedSearchIsRedactedInTheHeader(t *testing.T) {
	rules, err := logcore.DefaultRules()
	if err != nil {
		t.Fatal(err)
	}
	line := "2026-08-31 11:50:40.872 ERROR   APP (Main): lost 192.168.1.42 for dpierron\n"
	store := logcore.NewStore(rules, &logcore.BytesBuffer{Data: []byte(line)})
	store.IndexNew(0)
	f := logcore.NewFilterSet()
	f.TextFilters = []logcore.TextFilter{{Pattern: "192.168.1.42 dpierron"}}
	x, err := BuildExcerpt(testRedactor, store, &f, nil, DefaultMaxChars)
	if err != nil {
		t.Fatal(err)
	}
	header := strings.SplitN(x.Text(), "\n", 3)[1]
	if strings.Contains(header, "192.168") || strings.Contains(header, "dpierron") || !strings.Contains(header, "<ip> <user>") {
		t.Fatalf("search not redacted: %q", header)
	}
}
