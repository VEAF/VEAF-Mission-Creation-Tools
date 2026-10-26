package logview

import (
	"reflect"
	"regexp"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

var scriptError = logcore.Entry{
	Lineno: 5, Raw: "2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error: CSAR.lua:2213",
	Timestamp: "2026-08-31 11:55:01.930", Level: "ERROR", Message: "Mission script error: CSAR.lua:2213",
	Source: "dcs", SourceLabel: "SCRIPTING",
	Continuation: []string{"stack traceback:", "\t[C]: in function 'getUnitRecordById'"},
}

var veafLine = logcore.Entry{
	Lineno: 2, Raw: "2026-08-31 11:50:41.000 INFO    SCRIPTING (Main): VEAF|I|5390: Loading version 6.16.5",
	Timestamp: "2026-08-31 11:50:41.000", Level: "INFO", Message: "Loading version 6.16.5",
	Source: "veaf", SourceLabel: "VEAF", Module: "GRASS",
}

func TestCells(t *testing.T) {
	for _, c := range []struct {
		e    logcore.Entry
		col  int
		want string
	}{
		{scriptError, ColLine, "5"},
		{scriptError, ColTime, "11:55:01.930"},
		{scriptError, ColLevel, "ERROR"},
		{scriptError, ColSource, "SCRIPTING"},
		{veafLine, ColSource, "VEAF-GRASS"},
		{scriptError, ColMessage, "Mission script error: CSAR.lua:2213  [+2]"},
		{veafLine, ColMessage, "Loading version 6.16.5"},
		{logcore.Entry{Raw: "=== Log opened"}, ColMessage, "=== Log opened"},
		{logcore.Entry{Timestamp: "11:50:40"}, ColTime, "11:50:40"},
	} {
		if got := Cell(c.e, c.col); got != c.want {
			t.Errorf("Cell(%d, col %d) = %q, want %q", c.e.Lineno, c.col, got, c.want)
		}
	}
}

func TestCopyKeepsTheStackTrace(t *testing.T) {
	got := CopyText([]logcore.Entry{veafLine, scriptError}, false)
	want := veafLine.Raw + "\n" + scriptError.Raw + "\nstack traceback:\n\t[C]: in function 'getUnitRecordById'"
	if got != want {
		t.Errorf("copy\n got %q\nwant %q", got, want)
	}
	if got := CopyText([]logcore.Entry{veafLine, scriptError}, true); got != "Loading version 6.16.5\nMission script error: CSAR.lua:2213" {
		t.Errorf("message only: %q", got)
	}
}

func TestCopyReportAndMenu(t *testing.T) {
	if CopyReport(0) != "Rien de sélectionné à copier." || CopyReport(1) != "1 ligne copiée." || CopyReport(3) != "3 lignes copiées." {
		t.Error("copy report")
	}
	if w, m := ContextMenuLabels(1); w != "Copier la ligne" || m != "Copier le message sans l'en-tête" {
		t.Error(w, m)
	}
	if w, m := ContextMenuLabels(4); w != "Copier les 4 lignes" || m != "Copier les messages sans l'en-tête" {
		t.Error(w, m)
	}
}

func TestCellColours(t *testing.T) {
	rules, err := logcore.DefaultRules()
	if err != nil {
		t.Fatal(err)
	}
	if CellColor(rules, scriptError, ColTime) != GreyColumn || CellColor(rules, scriptError, ColLine) != GreyColumn {
		t.Error("line and time are grey")
	}
	if CellColor(rules, scriptError, ColMessage) != rules.LevelStyle("ERROR").Color {
		t.Error("message takes the level colour")
	}
	if CellColor(rules, veafLine, ColSource) != rules.SourceColor("veaf") {
		t.Error("source takes the source colour")
	}
}

func TestHighlightSpans(t *testing.T) {
	zone := regexp.MustCompile("(?i)zone")
	one := regexp.MustCompile("one int")
	empty := regexp.MustCompile("x*")
	got := HighlightSpans("VEAF zone introuvable, zone", []*regexp.Regexp{zone, one, empty})
	// "zone" at 5–9 and "one int" at 6–13 overlap and fuse; the second "zone" stands alone.
	want := [][2]int{{5, 13}, {23, 27}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("spans %v, want %v", got, want)
	}
	if HighlightSpans("nothing", []*regexp.Regexp{zone}) != nil {
		t.Error("no match, no span")
	}
}

func TestFontBounds(t *testing.T) {
	for in, want := range map[int]int{9: 9, 2: MinFontSize, -4: MinFontSize, 99: MaxFontSize} {
		if got := ClampFontSize(in); got != want {
			t.Errorf("ClampFontSize(%d) = %d", in, got)
		}
	}
}

func TestMessageWidth(t *testing.T) {
	if got := MessageWidth(100, 7, 300); got != (100+MessageMarginChars)*7 {
		t.Errorf("longest message wins: %d", got)
	}
	if got := MessageWidth(10, 7, 900); got != 900 {
		t.Errorf("short lines fill the room: %d", got)
	}
	if got := MessageWidth(0, 7, 50); got != 200 {
		t.Errorf("floor of 200: %d", got)
	}
}
