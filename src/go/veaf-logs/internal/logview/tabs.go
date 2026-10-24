package logview

// Strip is the model of the tab strip: which tabs, in which order, which one
// is current. The Win32 tab control can neither close nor reorder a tab and
// cannot be darkened (ADR 0022), so the strip is drawn by us and this is its logic.
type Strip[T any] struct {
	Items  []T
	Active int // -1 when there is no tab
}

// NewStrip is an empty strip.
func NewStrip[T any]() *Strip[T] { return &Strip[T]{Active: -1} }

// Insert adds a tab at `at` (out of range: at the end) and makes it current.
func (s *Strip[T]) Insert(item T, at int) int {
	if at < 0 || at > len(s.Items) {
		at = len(s.Items)
	}
	s.Items = append(s.Items, item)
	copy(s.Items[at+1:], s.Items[at:])
	s.Items[at] = item
	s.Active = at
	return at
}

// Remove closes the tab at i. Closing the current tab selects the one to its
// right, or the last one — QTabWidget's default; the current tab otherwise stays current.
func (s *Strip[T]) Remove(i int) (T, bool) {
	var zero T
	if i < 0 || i >= len(s.Items) {
		return zero, false
	}
	item := s.Items[i]
	s.Items = append(s.Items[:i], s.Items[i+1:]...)
	switch {
	case len(s.Items) == 0:
		s.Active = -1
	case i < s.Active:
		s.Active--
	case i == s.Active:
		s.Active = min(i, len(s.Items)-1)
	}
	return item, true
}

// Move takes the tab at `from` to `to`; the current tab stays current wherever it lands.
func (s *Strip[T]) Move(from, to int) {
	n := len(s.Items)
	if from < 0 || from >= n || to < 0 || to >= n || from == to {
		return
	}
	activeWasFrom := s.Active == from
	item := s.Items[from]
	if from < to {
		copy(s.Items[from:to], s.Items[from+1:to+1])
	} else {
		copy(s.Items[to+1:from+1], s.Items[to:from])
	}
	s.Items[to] = item
	switch {
	case activeWasFrom:
		s.Active = to
	case s.Active >= 0:
		// Shifted by one when the moved tab crossed it.
		if from < s.Active && to >= s.Active {
			s.Active--
		} else if from > s.Active && to <= s.Active {
			s.Active++
		}
	}
}

// Current is the current tab, if any.
func (s *Strip[T]) Current() (T, bool) {
	var zero T
	if s.Active < 0 || s.Active >= len(s.Items) {
		return zero, false
	}
	return s.Items[s.Active], true
}

// Span is the horizontal extent of one drawn tab, and of its close button.
type Span struct {
	X, Width           int
	CloseX, CloseWidth int
}

// LayoutTabs places tabs of the given label widths from x = start, `gap`
// apart; each tab is its label plus `padding` on both sides plus a close
// button of `closeWidth` at its right.
func LayoutTabs(labelWidths []int, start, gap, padding, closeWidth int) []Span {
	spans := make([]Span, len(labelWidths))
	x := start
	for i, w := range labelWidths {
		width := padding + w + padding + closeWidth
		spans[i] = Span{X: x, Width: width, CloseX: x + width - closeWidth - padding/2, CloseWidth: closeWidth}
		x += width + gap
	}
	return spans
}

// HitTest tells which tab is under x, and whether x is on its close button; -1 when none.
func HitTest(spans []Span, x int) (index int, onClose bool) {
	for i, s := range spans {
		if x >= s.X && x < s.X+s.Width {
			return i, x >= s.CloseX && x < s.CloseX+s.CloseWidth
		}
	}
	return -1, false
}

// DropIndex is where a tab dragged to x lands: the tab under x, or the last one past the end.
func DropIndex(spans []Span, x int) int {
	if len(spans) == 0 {
		return -1
	}
	if i, _ := HitTest(spans, x); i >= 0 {
		return i
	}
	if x < spans[0].X {
		return 0
	}
	return len(spans) - 1
}
