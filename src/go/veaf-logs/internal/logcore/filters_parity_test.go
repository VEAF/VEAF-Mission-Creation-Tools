package logcore

import (
	"bufio"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

type filterGolden struct {
	Case    string          `json:"case"`
	Filters json.RawMessage `json:"filters"`
	Visible [][2]int        `json:"visible"`
	Error   bool            `json:"error"`
}

func runs(indices []int) [][2]int {
	out := [][2]int{}
	for _, i := range indices {
		if n := len(out); n > 0 && out[n-1][1] == i-1 {
			out[n-1][1] = i
		} else {
			out = append(out, [2]int{i, i})
		}
	}
	return out
}

// TestFilterParityWithPython evaluates every enumerated filter case of
// gen_golden.py on every corpus file and compares the visible entries with what
// the Python `evaluate` returned. The filters are read from the JSON Python's
// `to_dict` wrote, so the reader is exercised by the same cases.
func TestFilterParityWithPython(t *testing.T) {
	rules := loadRules(t)
	files, err := filepath.Glob("../../testdata/corpus/*.log")
	if err != nil || len(files) == 0 {
		t.Fatalf("no corpus found: %v", err)
	}
	checked := 0
	for _, file := range files {
		name := strings.TrimSuffix(filepath.Base(file), ".log")
		t.Run(name, func(t *testing.T) {
			data, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			store := NewStore(rules, &BytesBuffer{Data: data})
			store.IndexNew(0)

			golden, err := os.Open("../../testdata/golden/" + name + ".filters.jsonl")
			if err != nil {
				t.Fatal(err)
			}
			defer golden.Close()
			scanner := bufio.NewScanner(golden)
			scanner.Buffer(make([]byte, 1<<20), 1<<20)
			bad := 0
			for scanner.Scan() {
				var want filterGolden
				if err := json.Unmarshal(scanner.Bytes(), &want); err != nil {
					t.Fatal(err)
				}
				var filters FilterSet
				if err := json.Unmarshal(want.Filters, &filters); err != nil {
					t.Fatalf("%s: %v", want.Case, err)
				}
				got, err := Evaluate(store, &filters)
				checked++
				var pe *PatternError
				switch {
				case want.Error:
					if !errors.As(err, &pe) {
						bad++
						t.Errorf("%s: Python refuses the pattern, Go returned %v", want.Case, err)
					}
				case err != nil:
					bad++
					t.Errorf("%s: %v", want.Case, err)
				default:
					if want.Visible == nil {
						want.Visible = [][2]int{}
					}
					if r := runs(got); !reflect.DeepEqual(r, want.Visible) {
						bad++
						if bad <= 5 {
							t.Errorf("%s\n python: %v\n     go: %v", want.Case, want.Visible, r)
						}
					}
				}
			}
			if bad > 5 {
				t.Errorf("%d cases differ in all", bad)
			}
		})
	}
	if checked < 500 {
		t.Errorf("only %d filter cases checked: the golden is not what gen_golden.py writes", checked)
	}
}
