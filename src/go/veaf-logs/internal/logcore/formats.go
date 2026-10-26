package logcore

import "regexp"

// HeaderFormat is one shape of line header (port of parser.HeaderFormat).
type HeaderFormat struct {
	ID           string
	Pattern      string
	LevelMap     map[string]string
	DefaultLevel string
	Scripts      bool // the Lua script prefixes (VEAF, CTLD...) apply
}

var levelLetters = map[string]string{"T": "TRACE", "D": "DEBUG", "I": "INFO", "W": "WARNING", "E": "ERROR"}
var levelAliases = map[string]string{"WARN": "WARNING", "FATAL": "ALERT", "PANIC": "ALERT", "DPANIC": "ALERT", "CRITICAL": "ALERT"}

// LogOpenedPattern is the opening line DCS writes at the top of a file.
const LogOpenedPattern = `^=== Log (?P<what>opened|closed) UTC (?P<stamp>.+)$`

// Formats, in the order they are tried: DCS first. Mirrors parser.FORMATS.
var Formats = []HeaderFormat{
	{ID: "dcs", Scripts: true, DefaultLevel: "UNKNOWN", Pattern: `^(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2}\.\d+) +` +
		`(?P<level>[A-Z][A-Z_]*) +` +
		`(?P<subsystem>[A-Za-z_][A-Za-z0-9_:]*)? *` +
		`\((?P<thread>[^)]*)\): ?(?P<message>.*)$`},
	{ID: "dcssb", LevelMap: levelAliases, DefaultLevel: "UNKNOWN", Pattern: `^(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2}[.,]\d+)[ \t]` +
		`(?P<level>[A-Z]+)\t(?P<message>.*)$`},
	{ID: "realweather", LevelMap: levelAliases, DefaultLevel: "UNKNOWN", Pattern: `^(?P<date>\d{4}-\d{2}-\d{2})T(?P<time>\d{2}:\d{2}:\d{2}\.\d+)[+-]\d{4}\t` +
		`(?P<level>[A-Z]+)\t(?P<message>.*)$`},
	{ID: "lotatc", LevelMap: levelLetters, DefaultLevel: "UNKNOWN", Pattern: `^\[(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2})[^\]]*\] ` +
		`\[(?P<level>[A-Z])\] (?P<message>(?:\[(?P<subsystem>[\w.:]+)\] )?.*)$`},
	{ID: "dcssb-async", DefaultLevel: "ERROR", Pattern: `^(?P<date>\d{4}-\d{2}-\d{2})T(?P<time>\d{2}:\d{2}:\d{2}\.\d+): (?P<message>.*)$`},
	{ID: "bracket", Scripts: true, DefaultLevel: "UNKNOWN", Pattern: `^\[(?P<time>[^\]]*)\] +(?P<level>[A-Z][A-Z_]*) +` +
		`(?P<subsystem>[A-Za-z_][A-Za-z0-9_:]*): ?(?P<message>.*)$`},
}

const dcsFormatIndex = 0

// compiledFormat is a header pattern with the positions of its named groups
// (-1 when the format has no such group).
type compiledFormat struct {
	re                                    *regexp.Regexp
	date, time, level, subsystem, message int
}

func compileFormat(f HeaderFormat) compiledFormat {
	re := regexp.MustCompile(f.Pattern)
	return compiledFormat{re: re,
		date: re.SubexpIndex("date"), time: re.SubexpIndex("time"), level: re.SubexpIndex("level"),
		subsystem: re.SubexpIndex("subsystem"), message: re.SubexpIndex("message")}
}
