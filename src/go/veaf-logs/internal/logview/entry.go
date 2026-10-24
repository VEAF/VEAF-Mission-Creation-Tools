// Package logview holds what the window shows, without the window: the
// document behind a tab, the cells of the table, the text copied, the
// appearance and the tab strip. Everything here is plain Go and tested; the
// walk window (internal/ui) only draws it.
package logview

import (
	"fmt"
	"strings"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// The table's columns, in order (ui/model.py).
const (
	ColLine = iota
	ColTime
	ColLevel
	ColSource
	ColMessage
	ColumnCount
)

// Headers are the column titles.
var Headers = [ColumnCount]string{"Ligne", "Heure", "Niveau", "Source", "Message"}

// Fixed widths of the four first columns, in pixels at 96 DPI; the message takes the rest.
var FixedWidths = [ColMessage]int{68, 92, 78, 130}

// GreyColumn is the colour of the line and time columns.
const GreyColumn = "#6e7681"

// Text is the whole entry, continuation lines included: what is copied and
// what the detail panel shows.
func Text(e logcore.Entry) string {
	if len(e.Continuation) == 0 {
		return e.Raw
	}
	return strings.Join(append([]string{e.Raw}, e.Continuation...), "\n")
}

// TimeOnly is the timestamp without its date.
func TimeOnly(e logcore.Entry) string {
	if len(e.Timestamp) > 11 {
		return e.Timestamp[11:]
	}
	return e.Timestamp
}

// MessageOrRaw is the message, or the raw line when it has no header.
func MessageOrRaw(e logcore.Entry) string {
	if e.Message != "" {
		return e.Message
	}
	return e.Raw
}

// Cell is the text of one cell. A folded stack trace is announced by `[+N]`.
func Cell(e logcore.Entry, col int) string {
	switch col {
	case ColLine:
		return fmt.Sprint(e.Lineno)
	case ColTime:
		return TimeOnly(e)
	case ColLevel:
		return e.Level
	case ColSource:
		if e.Module != "" {
			return e.SourceLabel + "-" + e.Module
		}
		return e.SourceLabel
	}
	message := MessageOrRaw(e)
	if n := len(e.Continuation); n > 0 {
		return fmt.Sprintf("%s  [+%d]", message, n)
	}
	return message
}

// CellColor is the foreground colour of a cell (#rrggbb).
func CellColor(rules *logcore.Rules, e logcore.Entry, col int) string {
	switch col {
	case ColSource:
		return rules.SourceColor(e.Source)
	case ColLine, ColTime:
		return GreyColumn
	}
	return rules.LevelStyle(e.Level).Color
}

// CopyText is what the clipboard receives for the given entries: each one
// whole — an entry carries its stack trace, and a `Mission script error` copied
// without it explains nothing — or, with messageOnly, its message alone.
func CopyText(entries []logcore.Entry, messageOnly bool) string {
	lines := make([]string, len(entries))
	for i, e := range entries {
		if messageOnly {
			lines[i] = MessageOrRaw(e)
		} else {
			lines[i] = Text(e)
		}
	}
	return strings.Join(lines, "\n")
}

// CopyReport is the status message after a copy.
func CopyReport(count int) string {
	switch count {
	case 0:
		return "Rien de sélectionné à copier."
	case 1:
		return "1 ligne copiée."
	}
	return fmt.Sprintf("%d lignes copiées.", count)
}

// ContextMenuLabels are the two entries of the table's context menu for a selection of `count` rows.
func ContextMenuLabels(count int) (whole, message string) {
	if count == 1 {
		return "Copier la ligne", "Copier le message sans l'en-tête"
	}
	return fmt.Sprintf("Copier les %d lignes", count), "Copier les messages sans l'en-tête"
}
