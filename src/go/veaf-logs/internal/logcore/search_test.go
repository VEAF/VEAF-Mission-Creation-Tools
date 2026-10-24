package logcore

import (
	"os"
	"reflect"
	"strings"
	"testing"
)

// The search must give what a brute-force scan of every decoded entry gives.
func TestSearchMatchesBruteForce(t *testing.T) {
	rules := loadRules(t)
	for _, name := range []string{"dcs-handwritten", "mixed", "fuzz-1", "fuzz-2"} {
		data, err := os.ReadFile("../../testdata/corpus/" + name + ".log")
		if err != nil {
			t.Fatal(err)
		}
		store := NewStore(rules, &BytesBuffer{Data: data})
		store.IndexNew(0)
		for _, needle := range []string{"veaf", "STACK", "row", "error", "CTLD][INFO", "zzz-none", "é", "\t"} {
			var want []int32
			for i := 0; i < store.Len(); i++ {
				e := store.Entry(i)
				text := strings.Join(append([]string{e.Raw}, e.Continuation...), "\n")
				if strings.Contains(asciiLowerString(text), asciiLowerString(needle)) {
					want = append(want, int32(i))
				}
			}
			got := store.Search(needle, nil)
			if !reflect.DeepEqual(want, got) && !(len(want) == 0 && len(got) == 0) {
				t.Errorf("%s %q: brute force %d hits, Search %d", name, needle, len(want), len(got))
			}
		}
	}
}

func asciiLowerString(s string) string { return string(asciiLower([]byte(s))) }
