package analysis

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// The `veaf-tools doctor` block (`veaf_libs.diagnostics`): which tool, which
// DCS, which machine — the facts a bug report always misses. Its format is a
// contract the support bot reads; the values are this executable's.

const (
	doctorSchema = "veaf-tools-doctor/1"
	DoctorStart  = "=== VEAF-TOOLS DOCTOR BEGIN ==="
	DoctorEnd    = "=== VEAF-TOOLS DOCTOR END ==="
	errorsStart  = "--- recent-errors ---"
	errorsEnd    = "--- recent-errors end ---"

	// Unknown is what a field says when the machine cannot answer.
	Unknown = "unknown"

	defaultErrorCount = 3
	maxLinesPerError  = 25
	logTailBytes      = 512 * 1024
	maxRolledLogs     = 9
	dcsHeaderLines    = 100
)

// Version is this executable's version, stamped at build time
// (-ldflags "-X …/internal/analysis.Version=6.31.4").
var Version = Unknown

// fieldOrder is the contract: the fields, in the order the block writes them.
var fieldOrder = []string{
	"schema", "generated",
	"tool.version", "tool.packaging", "tool.executable", "tool.python",
	"machine.os", "machine.locale", "machine.free_space",
	"dcs.detected", "dcs.version", "dcs.variant", "dcs.write_dir", "dcs.log_age",
	"veaf.home", "veaf.log", "veaf.lua_modules",
}

var (
	lineBreaks   = regexp.MustCompile(`[\r\n]+`)
	recordHeader = regexp.MustCompile(`^` + strings.ReplaceAll(`\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}`, `\d`, `[`+pyD+`]`) + ` - [^` + pyS + `]+ - ([A-Z]+) - `)
	dcsVersion   = regexp.MustCompile(`DCS/([` + pyD + `]+(?:\.[` + pyD + `]+)+)`)
	luaModuleID  = regexp.MustCompile(`(veaf[` + pyW + `]+)\.Id[` + pyS + `]*=[` + pyS + `]*"([^"]+)"`)
)

// DiagnosticReport is one collection pass: the fields, and the recent error records.
type DiagnosticReport struct {
	Fields       map[string]string
	RecentErrors []string
}

// oneLine keeps one field on one line: a value carrying a newline would come back as two fields.
func oneLine(s string) string { return pyStrip(lineBreaks.ReplaceAllString(s, " ")) }

// Block renders the paste block.
func (d DiagnosticReport) Block() string {
	lines := []string{DoctorStart}
	for _, name := range orderedFields(d.Fields) {
		lines = append(lines, oneLine(name)+": "+oneLine(d.Fields[name]))
	}
	if len(d.RecentErrors) > 0 {
		lines = append(lines, errorsStart)
		for _, r := range d.RecentErrors {
			lines = append(lines, pySplitLines(r)...)
		}
		lines = append(lines, errorsEnd)
	}
	lines = append(lines, DoctorEnd)
	return strings.Join(lines, "\n")
}

// orderedFields lists the contract's fields first, then any other, sorted.
func orderedFields(fields map[string]string) []string {
	var out, extras []string
	known := map[string]bool{}
	for _, name := range fieldOrder {
		known[name] = true
		if _, ok := fields[name]; ok {
			out = append(out, name)
		}
	}
	for name := range fields {
		if !known[name] {
			extras = append(extras, name)
		}
	}
	sort.Strings(extras)
	return append(out, extras...)
}

func humaniseAge(seconds float64) string {
	switch {
	case seconds < 60:
		return fmt.Sprintf("%d s", int(seconds))
	case seconds < 3600:
		return fmt.Sprintf("%d min", int(seconds/60))
	case seconds < 86400:
		return fmt.Sprintf("%d h", int(seconds/3600))
	}
	return fmt.Sprintf("%d d", int(seconds/86400))
}

func humaniseSize(size int64) string {
	switch {
	case size < 1024:
		return fmt.Sprintf("%d B", size)
	case size < 1024*1024:
		return fmt.Sprintf("%.0f KB", float64(size)/1024)
	}
	return fmt.Sprintf("%.1f MB", float64(size)/(1024*1024))
}

// dcsVariant names the branch a write folder belongs to (`DCS.openbeta` → `openbeta`).
func dcsVariant(folder string) string {
	suffix := strings.TrimLeft(folder[min(3, len(folder)):], "._-")
	if suffix == "" {
		return "stable"
	}
	return strings.ToLower(suffix)
}

// readDCSVersion reads the version DCS states on the sixth line of its log.
func readDCSVersion(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return Unknown
	}
	defer f.Close()
	data := make([]byte, 1<<20)
	n, _ := io.ReadFull(f, data)
	text := decodeReplace(data[:n])
	lines := 0
	for len(text) > 0 && lines < dcsHeaderLines {
		line := text
		if i := strings.IndexAny(text, "\n"); i >= 0 {
			line, text = text[:i+1], text[i+1:]
		} else {
			text = ""
		}
		lines++
		if m := dcsVersion.FindStringSubmatchIndex(line); m != nil {
			// \bDCS: refused after a word character, tried again further on.
			for m != nil {
				if r, ok := before(line, m[0]); !ok || !isWord(r) {
					return line[m[2]:m[3]]
				}
				next := dcsVersion.FindStringSubmatchIndex(line[m[0]+1:])
				if next == nil {
					break
				}
				for k := range next {
					next[k] += m[0] + 1
				}
				m = next
			}
		}
	}
	return Unknown
}

// decodeReplace decodes like Python's errors="replace".
func decodeReplace(b []byte) string { return logcore.DecodeUTF8(b) }

// dcsWriteDirs are the Saved Games folders holding a DCS log, freshest first.
func dcsWriteDirs(savedGames string) []string {
	entries, err := os.ReadDir(savedGames)
	if err != nil {
		return nil
	}
	type candidate struct {
		path  string
		mtime time.Time
	}
	var found []candidate
	for _, e := range entries {
		if !e.IsDir() || !strings.HasPrefix(strings.ToUpper(e.Name()), "DCS") {
			continue
		}
		dir := filepath.Join(savedGames, e.Name())
		if info, err := os.Stat(filepath.Join(dir, "Logs", "dcs.log")); err == nil && info.Mode().IsRegular() {
			found = append(found, candidate{dir, info.ModTime()})
		}
	}
	sort.SliceStable(found, func(i, j int) bool { return found[i].mtime.After(found[j].mtime) })
	out := make([]string, len(found))
	for i, c := range found {
		out[i] = c.path
	}
	return out
}

func collectDCS(r *Redactor, savedGames string, now time.Time) map[string]string {
	dirs := dcsWriteDirs(savedGames)
	if len(dirs) == 0 {
		return map[string]string{"dcs.detected": "no"}
	}
	dir := dirs[0]
	log := filepath.Join(dir, "Logs", "dcs.log")
	out := map[string]string{
		"dcs.detected":  "yes",
		"dcs.version":   readDCSVersion(log),
		"dcs.variant":   dcsVariant(filepath.Base(dir)),
		"dcs.write_dir": r.Redact(dir),
	}
	if info, err := os.Stat(log); err == nil {
		out["dcs.log_age"] = humaniseAge(now.Sub(info.ModTime()).Seconds())
	}
	return out
}

// veafHome is $VEAF_HOME, else ~/.veaf — created, as the Python does.
func veafHome() string {
	home := strings.TrimSpace(os.Getenv("VEAF_HOME"))
	if home == "" {
		h, _ := os.UserHomeDir()
		home = filepath.Join(h, ".veaf")
	}
	_ = os.MkdirAll(home, 0o755)
	return home
}

// luaModuleCount counts the VEAF Lua modules of the nearest `src/scripts/veaf`
// above `from`: a checkout of the repository. A shipped executable finds none,
// like the shipped Python one, which has no module list in its bundle.
func luaModuleCount(from string) int {
	dir, err := filepath.Abs(from)
	if err != nil {
		return 0
	}
	for i := 0; i < 12; i++ {
		lua := filepath.Join(dir, "src", "scripts", "veaf")
		if info, err := os.Stat(lua); err == nil && info.IsDir() {
			files, _ := filepath.Glob(filepath.Join(lua, "veaf*.lua"))
			n := 0
			for _, f := range files {
				if data, err := os.ReadFile(f); err == nil && hasModuleID(string(bytes.ToValidUTF8(data, nil))) {
					n++
				}
			}
			return n
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return 0
}

// hasModuleID is `(veaf\w+)\.Id\s*=\s*"…"` found somewhere in a Lua file.
func hasModuleID(text string) bool {
	for _, m := range luaModuleID.FindAllStringIndex(text, -1) {
		if r, ok := before(text, m[0]); !ok || !isWord(r) {
			return true
		}
	}
	return false
}

func collectVEAF(r *Redactor, executable string) map[string]string {
	home := veafHome()
	state := "absent"
	if info, err := os.Stat(filepath.Join(home, "veaf-tools.log")); err == nil && info.Mode().IsRegular() {
		state = "present, " + humaniseSize(info.Size())
	}
	return map[string]string{
		"veaf.home":        r.Redact(home),
		"veaf.log":         state,
		"veaf.lua_modules": fmt.Sprint(luaModuleCount(filepath.Dir(executable))),
	}
}

// RecentErrors returns the last error records of the tool's log and of the
// rolled-over files behind it, oldest first, capped and redacted.
func RecentErrors(r *Redactor, count int, path string) []string {
	if count <= 0 {
		return nil
	}
	files := []string{path}
	for i := 1; i <= maxRolledLogs; i++ {
		rolled := fmt.Sprintf("%s.%d", path, i)
		if info, err := os.Stat(rolled); err != nil || !info.Mode().IsRegular() {
			break
		}
		files = append(files, rolled)
	}
	var records [][]string
	for _, f := range files {
		records = append(errorRecords(f), records...)
		if len(records) >= count {
			break
		}
	}
	if len(records) > count {
		records = records[len(records)-count:]
	}
	out := make([]string, 0, len(records))
	for _, rec := range records {
		if len(rec) > maxLinesPerError {
			rec = rec[:maxLinesPerError]
		}
		lines := make([]string, len(rec))
		for i, l := range rec {
			lines[i] = capLine(l)
		}
		out = append(out, r.Redact(strings.Join(lines, "\n")))
	}
	return out
}

func errorRecords(path string) [][]string {
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() {
		return nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	if _, err := f.Seek(max(0, info.Size()-logTailBytes), 0); err != nil {
		return nil
	}
	data := make([]byte, min(info.Size(), logTailBytes))
	n, _ := io.ReadFull(f, data)
	var records [][]string
	keeping := false
	for _, line := range pySplitLines(decodeReplace(data[:n])) {
		if m := recordHeader.FindStringSubmatch(line); m != nil {
			keeping = m[1] == "ERROR" || m[1] == "CRITICAL"
			if keeping {
				records = append(records, []string{line})
			}
			continue
		}
		if keeping && len(records) > 0 {
			records[len(records)-1] = append(records[len(records)-1], line)
		}
	}
	return records
}

// CollectDoctor collects every field; one that cannot be answered is Unknown, and nothing fails.
func CollectDoctor(r *Redactor, now time.Time) DiagnosticReport {
	fields := map[string]string{}
	for _, name := range fieldOrder {
		fields[name] = Unknown
	}
	set := func(m map[string]string) {
		for k, v := range m {
			if v != "" {
				fields[k] = v
			}
		}
	}
	executable, _ := os.Executable()
	set(map[string]string{
		"schema":          doctorSchema,
		"generated":       now.UTC().Format("2006-01-02T15:04:05Z"),
		"tool.version":    Version,
		"tool.packaging":  "frozen",
		"tool.executable": r.Redact(executable),
		"tool.python":     runtime.Version(),
	})
	set(machineFields(r))
	set(collectDCS(r, savedGamesDir(), now))
	set(collectVEAF(r, executable))
	return DiagnosticReport{Fields: fields, RecentErrors: RecentErrors(r, defaultErrorCount, filepath.Join(veafHome(), "veaf-tools.log"))}
}
