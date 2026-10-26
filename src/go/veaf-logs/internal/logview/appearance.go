package logview

// Font of the journal (appearance.py): one definition, shared by the table and
// the detail panel.
const (
	DefaultFontFamily = "Cascadia Mono"
	DefaultFontSize   = 9
	// Below 6 points the journal is unreadable, above 36 a line no longer fits
	// on screen: a held mouse wheel must not make the tool unusable.
	MinFontSize = 6
	MaxFontSize = 36
)

// ClampFontSize brings a size within bounds.
func ClampFontSize(size int) int {
	return max(MinFontSize, min(MaxFontSize, size))
}

// MessageMarginChars is the margin of the message column, in characters: the
// `[+3]` of a folded trace, and room not to touch the edge.
const MessageMarginChars = 8

// MessageWidth is the width of the message column: wide enough for the longest
// message — so a horizontal scroll bar reaches the end of the longest line —
// and at least the room left, so a journal of short lines leaves no empty band.
func MessageWidth(longestChars, charWidth, available int) int {
	return max((longestChars+MessageMarginChars)*charWidth, available, 200)
}
