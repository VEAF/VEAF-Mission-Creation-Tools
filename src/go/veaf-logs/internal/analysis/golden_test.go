package analysis

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// testdata is where gen_analysis_golden.py writes the Python's references.
var testdata = filepath.Join("..", "..", "testdata", "analysis")

// The account the references were generated for (gen_analysis_golden.py).
var testRedactor = NewRedactor("Jean Dupont", "dpierron")

// readJSONL decodes one reference file, one record per line.
func readJSONL[T any](t *testing.T, name string) []T {
	t.Helper()
	f, err := os.Open(filepath.Join(testdata, name))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	var out []T
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<26)
	for sc.Scan() {
		var v T
		if err := json.Unmarshal(sc.Bytes(), &v); err != nil {
			t.Fatal(err)
		}
		out = append(out, v)
	}
	if err := sc.Err(); err != nil {
		t.Fatal(err)
	}
	if len(out) == 0 {
		t.Fatalf("%s: no reference", name)
	}
	return out
}

// reportDiff fails with the first differing case, and counts the rest.
func reportDiff(t *testing.T, what string, failures int, first string) {
	t.Helper()
	if failures > 0 {
		t.Fatalf("%d %s differ from the Python; first:\n%s", failures, what, first)
	}
}

func TestRedactIsThePythonOne(t *testing.T) {
	// The inputs are stored in base64: they hold fake tokens shaped like real ones.
	cases := readJSONL[struct {
		In  []byte `json:"in_b64"`
		Out string
	}](t, "redact.jsonl")
	failures, first := 0, ""
	for _, c := range cases {
		if got := testRedactor.Redact(string(c.In)); got != c.Out {
			if failures == 0 {
				first = "in:   " + string(c.In) + "\nwant: " + c.Out + "\ngot:  " + got
			}
			failures++
		}
	}
	reportDiff(t, "redactions", failures, first)
	t.Logf("%d redactions equal", len(cases))
}

func TestNormaliseIsThePythonOne(t *testing.T) {
	cases := readJSONL[struct{ Message, Normalised, Pattern, Verdict string }](t, "normalise.jsonl")
	failures, first := 0, ""
	for _, c := range cases {
		n := Normalise(c.Message)
		p := PatternFrom(n)
		v := ValidatePattern(p, pyStrip(c.Message))
		if n != c.Normalised || p != c.Pattern || v != c.Verdict {
			if failures == 0 {
				first = "message: " + c.Message + "\nwant: " + c.Normalised + " | " + c.Pattern + " | " + c.Verdict + "\ngot:  " + n + " | " + p + " | " + v
			}
			failures++
		}
	}
	reportDiff(t, "normalisations", failures, first)
	t.Logf("%d messages equal", len(cases))
}

// journal indexes one of the journals the references were written from.
func journal(t *testing.T, rules *logcore.Rules, name string) *logcore.Store {
	t.Helper()
	path := filepath.Join("..", "..", "testdata", "corpus", name+".log")
	if name == "analysis-journal" {
		path = filepath.Join(testdata, name+".log")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	store := logcore.NewStore(rules, &logcore.BytesBuffer{Data: data})
	store.IndexNew(0)
	return store
}

type analysisCase struct {
	Journal, Case string
	Filters       logcore.FilterSet
	MaxChars      int `json:"max_chars"`
	Text          string
}

func TestAnalysisTextIsThePythonOne(t *testing.T) {
	rules, err := logcore.DefaultRules()
	if err != nil {
		t.Fatal(err)
	}
	stores := map[string]*logcore.Store{}
	failures, first := 0, ""
	cases := readJSONL[analysisCase](t, "analysis.jsonl")
	for _, c := range cases {
		store := stores[c.Journal]
		if store == nil {
			store = journal(t, rules, c.Journal)
			stores[c.Journal] = store
		}
		a, err := Analyse(testRedactor, store, rules, &c.Filters, nil, c.MaxChars)
		if err != nil {
			t.Fatal(err)
		}
		if got := a.Text(); got != c.Text {
			if failures == 0 {
				first = fmt.Sprintf("%s / %s / %d:\n%s", c.Journal, c.Case, c.MaxChars, firstDifference(c.Text, got))
			}
			failures++
		}
	}
	reportDiff(t, "analyses", failures, first)
	t.Logf("%d analyses equal", len(cases))
}

// firstDifference shows the first line that differs, with its neighbours.
func firstDifference(want, got string) string {
	w, g := strings.Split(want, "\n"), strings.Split(got, "\n")
	for i := 0; i < len(w) || i < len(g); i++ {
		var a, b string
		if i < len(w) {
			a = w[i]
		}
		if i < len(g) {
			b = g[i]
		}
		if a != b {
			return fmt.Sprintf("line %d\nwant: %q\ngot:  %q", i+1, a, b)
		}
	}
	return "(equal lines, different text)"
}

func TestDoctorIsThePythonOne(t *testing.T) {
	type record struct {
		Kind, Name string
		Fields     map[string]string
		Errors     []string
		In         json.RawMessage
		Out        json.RawMessage
	}
	failures, first := 0, ""
	fail := func(what string, want, got any) {
		if failures == 0 {
			first = fmt.Sprintf("%s\nwant: %#v\ngot:  %#v", what, want, got)
		}
		failures++
	}
	for _, r := range readJSONL[record](t, "doctor.jsonl") {
		var wantText string
		_ = json.Unmarshal(r.Out, &wantText)
		switch r.Kind {
		case "block":
			if got := (DiagnosticReport{Fields: r.Fields, RecentErrors: r.Errors}).Block(); got != wantText {
				fail("block "+r.Name, wantText, got)
			}
		case "age":
			var in float64
			_ = json.Unmarshal(r.In, &in)
			if got := humaniseAge(in); got != wantText {
				fail(fmt.Sprint("age ", in), wantText, got)
			}
		case "size":
			var in int64
			_ = json.Unmarshal(r.In, &in)
			if got := humaniseSize(in); got != wantText {
				fail(fmt.Sprint("size ", in), wantText, got)
			}
		case "variant":
			var in string
			_ = json.Unmarshal(r.In, &in)
			if got := dcsVariant(in); got != wantText {
				fail("variant "+in, wantText, got)
			}
		case "dcs_version":
			var in string
			_ = json.Unmarshal(r.In, &in)
			path := filepath.Join("..", "..", "testdata", "corpus", in)
			if in == "analysis-journal.log" {
				path = filepath.Join(testdata, in)
			}
			if got := readDCSVersion(path); got != wantText {
				fail("dcs version "+in, wantText, got)
			}
		case "recent_errors":
			var in int
			var want []string
			_ = json.Unmarshal(r.In, &in)
			_ = json.Unmarshal(r.Out, &want)
			got := RecentErrors(testRedactor, in, filepath.Join(testdata, "veaf-tools.log"))
			if strings.Join(got, "\x00") != strings.Join(want, "\x00") || len(got) != len(want) {
				fail(fmt.Sprint("recent errors ", in), want, got)
			}
		default:
			t.Fatalf("unknown reference kind %q", r.Kind)
		}
	}
	reportDiff(t, "doctor values", failures, first)
}

func TestReportIsThePythonOne(t *testing.T) {
	rules, err := logcore.DefaultRules()
	if err != nil {
		t.Fatal(err)
	}
	doctors := map[string]*DiagnosticReport{"none": nil}
	for _, r := range readJSONL[struct {
		Kind, Name string
		Fields     map[string]string
		Errors     []string
	}](t, "doctor.jsonl") {
		if r.Kind == "block" {
			doctors[r.Name] = &DiagnosticReport{Fields: r.Fields, RecentErrors: r.Errors}
		}
	}
	frozen := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	stores := map[string]*logcore.Store{}
	failures, first := 0, ""
	cases := readJSONL[struct {
		Journal, Case, Commentary, Doctor, Block string
		ModelError                               string `json:"model_error"`
		Filters                                  logcore.FilterSet
		MaxChars                                 int `json:"max_chars"`
	}](t, "report.jsonl")
	for _, c := range cases {
		store := stores[c.Journal]
		if store == nil {
			store = journal(t, rules, c.Journal)
			stores[c.Journal] = store
		}
		doctor, ok := doctors[c.Doctor]
		if !ok {
			t.Fatalf("no doctor fixture %q", c.Doctor)
		}
		a, err := Analyse(testRedactor, store, rules, &c.Filters, nil, DefaultMaxChars)
		if err != nil {
			t.Fatal(err)
		}
		got := BuildReport(testRedactor, a.WithModel(c.Commentary, c.ModelError), doctor, c.MaxChars, frozen)
		if got != c.Block {
			if failures == 0 {
				first = fmt.Sprintf("%s / %s / doctor %s / %d:\n%s", c.Journal, c.Case, c.Doctor, c.MaxChars, firstDifference(c.Block, got))
			}
			failures++
		}
	}
	reportDiff(t, "report blocks", failures, first)
	t.Logf("%d report blocks equal", len(cases))
}
