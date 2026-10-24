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
