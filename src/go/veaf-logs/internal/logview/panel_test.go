package logview

import (
	"reflect"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

func keys(cats []Category) []string {
	out := make([]string, len(cats))
	for i, c := range cats {
		out[i] = c.Key
	}
	return out
}

func TestCategoriesFollowThePythonOrder(t *testing.T) {
	r := rules(t)
	levels := LevelCategories(r, map[string]int{"INFO": 9, "ERROR": 2, "DEBUG": 1, "WARNING": 3})
	if got := keys(levels); !reflect.DeepEqual(got, []string{"ERROR", "WARNING", "INFO", "DEBUG"}) {
		t.Errorf("levels in the catalogue's order: %v", got)
	}
	if levels[0].Color != r.LevelStyle("ERROR").Color {
		t.Error("level colour")
	}
	// Busiest first; "ctld" and "dcs" tie at 2 and keep their first appearance.
	sources := SourceCategories(r, map[string]int{"dcs": 2, "veaf": 5, "ctld": 2}, []string{"ctld", "dcs", "veaf"})
	if got := keys(sources); !reflect.DeepEqual(got, []string{"veaf", "ctld", "dcs"}) {
		t.Errorf("sources: %v", got)
	}
	if sources[2].Label != logcore.NativeLabel {
		t.Errorf("native label: %q", sources[2].Label)
	}
	var first logcore.NoiseFamily
	for _, f := range r.Noise {
		first = f
		break
	}
	noise := NoiseCategories(r, map[string]int{first.ID: 4, "never-met": 0})
	if len(noise) != 1 || noise[0].Key != first.ID || noise[0].Hint != first.Help || noise[0].Color != "" {
		t.Errorf("noise, only what was met: %+v", noise)
	}
}

func TestStatesCycleAndRead(t *testing.T) {
	s := logcore.StateOn
	var seen []logcore.State
	for i := 0; i < 3; i++ {
		s = NextState(s)
		seen = append(seen, s)
	}
	if !reflect.DeepEqual(seen, []logcore.State{logcore.StateContext, logcore.StateOff, logcore.StateOn}) {
		t.Errorf("cycle %v", seen)
	}
	c := Category{Label: "INFO", Count: 12}
	if RowText(c, logcore.StateContext) != " ◐  INFO  (12)" {
		t.Error(RowText(c, logcore.StateContext))
	}
	if RowTooltip(c, logcore.StateOff) != "État : masqué\nClic : état suivant" {
		t.Error(RowTooltip(c, logcore.StateOff))
	}
	c.Hint = "Cosmétique."
	if RowTooltip(c, logcore.StateOn) != "Cosmétique.\n\nÉtat : affiché\nClic : état suivant" {
		t.Error(RowTooltip(c, logcore.StateOn))
	}
}

// Setting a group leaves the categories this journal does not hold as they
// were: a profile hiding DEBUG keeps doing so on a journal with no DEBUG yet.
func TestSetAllKeepsAbsentCategories(t *testing.T) {
	f := logcore.NewFilterSet()
	f.Levels = map[string]logcore.State{"DEBUG": logcore.StateOff}
	SetAll(&f, "levels", []string{"INFO", "ERROR"}, logcore.StateContext)
	want := map[string]logcore.State{"DEBUG": logcore.StateOff, "INFO": logcore.StateContext, "ERROR": logcore.StateContext}
	if !reflect.DeepEqual(f.Levels, want) {
		t.Errorf("%v", f.Levels)
	}
	SetAll(&f, "levels", []string{"INFO", "ERROR"}, logcore.StateOn)
	if !reflect.DeepEqual(f.Levels, map[string]logcore.State{"DEBUG": logcore.StateOff}) {
		t.Errorf("back to shown: %v", f.Levels)
	}
	if StateOf(f, "levels", "DEBUG") != logcore.StateOff || StateOf(f, "sources", "x") != logcore.StateOn {
		t.Error("StateOf")
	}
}

func TestSpanTexts(t *testing.T) {
	own := 5
	if SpanSuffix(nil, 3) != " (3)" || SpanSuffix(&own, 3) != "" || SearchContextHint(2) != "(2)" {
		t.Error("span texts")
	}
}

func TestDocCounts(t *testing.T) {
	d, _ := localDoc(t, lineA+lineB+lineC)
	d.Start()
	waitFor(t, "indexed", func() bool { return d.Status().Total == 3 })
	c := d.Counts()
	if c.Levels["INFO"] != 2 || c.Levels["ERROR"] != 1 || len(c.SourceOrder) != 1 {
		t.Errorf("%+v", c)
	}
}
