package logview

import (
	"reflect"
	"testing"
)

func strip(items ...string) *Strip[string] {
	s := NewStrip[string]()
	for _, it := range items {
		s.Insert(it, -1)
	}
	return s
}

func TestInsertMakesCurrent(t *testing.T) {
	s := strip("a", "b")
	if s.Active != 1 {
		t.Errorf("active %d", s.Active)
	}
	s.Insert("x", 0)
	if !reflect.DeepEqual(s.Items, []string{"x", "a", "b"}) || s.Active != 0 {
		t.Errorf("%v active %d", s.Items, s.Active)
	}
}

func TestRemove(t *testing.T) {
	for _, c := range []struct {
		name          string
		active, close int
		wantItems     []string
		wantActive    int
	}{
		{"current, the right one takes over", 1, 1, []string{"a", "c"}, 1},
		{"current and last, the left one takes over", 2, 2, []string{"a", "b"}, 1},
		{"before the current", 2, 0, []string{"b", "c"}, 1},
		{"after the current", 0, 2, []string{"a", "b"}, 0},
	} {
		s := strip("a", "b", "c")
		s.Active = c.active
		s.Remove(c.close)
		if !reflect.DeepEqual(s.Items, c.wantItems) || s.Active != c.wantActive {
			t.Errorf("%s: %v active %d", c.name, s.Items, s.Active)
		}
	}
	s := strip("a")
	s.Remove(0)
	if s.Active != -1 || len(s.Items) != 0 {
		t.Error("last tab closed")
	}
	if _, ok := s.Remove(3); ok {
		t.Error("out of range")
	}
}

func TestMoveKeepsTheCurrentTab(t *testing.T) {
	for _, c := range []struct {
		active, from, to int
		want             []string
	}{
		{0, 0, 2, []string{"b", "c", "a"}},
		{1, 0, 2, []string{"b", "c", "a"}},
		{2, 2, 0, []string{"c", "a", "b"}},
		{0, 2, 0, []string{"c", "a", "b"}},
		{1, 2, 1, []string{"a", "c", "b"}},
	} {
		s := strip("a", "b", "c")
		s.Active = c.active
		current := s.Items[c.active]
		s.Move(c.from, c.to)
		if !reflect.DeepEqual(s.Items, c.want) {
			t.Errorf("move %d→%d: %v", c.from, c.to, s.Items)
		}
		if got, _ := s.Current(); got != current {
			t.Errorf("move %d→%d with %q current: now %q", c.from, c.to, current, got)
		}
	}
}

func TestLayoutAndHits(t *testing.T) {
	spans := LayoutTabs([]int{40, 60}, 6, 2, 10, 14)
	// Tab 0: 10 + 40 + 10 + 14 = 74 wide at x=6; tab 1 at 6+74+2 = 82.
	if spans[0].X != 6 || spans[0].Width != 74 || spans[1].X != 82 {
		t.Fatalf("%+v", spans)
	}
	if i, closing := HitTest(spans, 10); i != 0 || closing {
		t.Errorf("label of tab 0: %d %v", i, closing)
	}
	if i, closing := HitTest(spans, spans[1].CloseX+2); i != 1 || !closing {
		t.Errorf("close of tab 1: %d %v", i, closing)
	}
	if i, _ := HitTest(spans, 80); i != -1 {
		t.Errorf("the gap is no tab: %d", i)
	}
	if DropIndex(spans, 500) != 1 || DropIndex(spans, 0) != 0 || DropIndex(spans, 90) != 1 {
		t.Error("drop index")
	}
}

func TestScrollOffset(t *testing.T) {
	spans := LayoutTabs([]int{80, 80, 80, 80}, 0, 2, 10, 14) // each tab 114 wide, 116 apart
	total := ContentWidth(spans)
	if total != 4*114+3*2 {
		t.Fatalf("content width %d", total)
	}
	if ClampOffset(total, 1000, 300) != 0 {
		t.Error("no overflow, no scroll")
	}
	if got := ClampOffset(total, 200, 999); got != total-200 {
		t.Errorf("clamped to the overflow: %d", got)
	}
	if ClampOffset(total, 200, -5) != 0 {
		t.Error("never before the first tab")
	}
	// The last tab brought into a 200-px view: its right edge at the view's right.
	if got := ScrollIntoView(spans[3], 200, 0); got != spans[3].X+spans[3].Width-200 {
		t.Errorf("into view from the left: %d", got)
	}
	// The first tab from far right: its left edge at the view's left.
	if got := ScrollIntoView(spans[0], 200, 300); got != 0 {
		t.Errorf("into view from the right: %d", got)
	}
	// Already visible: the offset does not move.
	if got := ScrollIntoView(spans[1], 300, 50); got != 50 {
		t.Errorf("visible tab moved the strip: %d", got)
	}
	if ListButtonShown(1) || !ListButtonShown(2) {
		t.Error("the list button shows from two tabs on")
	}
}

func TestShortNames(t *testing.T) {
	veaf := []string{"VEAF (www.veaf.org) [fr] - Privé 1", "VEAF (www.veaf.org) [fr] - Privé 2", "VEAF (www.veaf.org) [fr] - Public Foothold 1"}
	if got := ShortNames(veaf); !reflect.DeepEqual(got, []string{"Privé 1", "Privé 2", "Public Foothold 1"}) {
		t.Errorf("veaf: %q", got)
	}
	cases := map[string][]string{
		"a single name is kept":            {"VEAF (www.veaf.org) [fr] - Privé 1"},
		"no shared word":                   {"alpha", "beta"},
		"cut only at a word boundary":      {"Training", "Trainer"},
		"a name would be left empty":       {"VEAF", "VEAF Private"},
		"nothing shared but a single word": {"VEAF A", "VEAFB"},
	}
	for name, in := range cases {
		if got := ShortNames(in); !reflect.DeepEqual(got, in) {
			t.Errorf("%s: %q", name, got)
		}
	}
}

func TestTabTitle(t *testing.T) {
	if got := TabTitle("veaf-api", "VEAF - Privé 1", "Privé 1", ""); got != "veaf-api:Privé 1" {
		t.Error(got)
	}
	if got := TabTitle("veaf-api", "VEAF - Privé 1", "", ""); got != "veaf-api:VEAF - Privé 1" {
		t.Error(got)
	}
	if got := TabTitle("veaf-api", "VEAF - Privé 1", "Privé 1", "P1"); got != "P1" {
		t.Error("an alias is the whole title:", got)
	}
}
