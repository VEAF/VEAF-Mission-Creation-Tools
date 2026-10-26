package analysis

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
)

// Redaction (`veaf_libs.redaction`): personal and secret material out of
// anything the user is invited to publish. The rules, their order and their
// exceptions are the Python's; its module docstring says why each one is there.

const (
	userPlaceholder   = "<user>"
	ipPlaceholder     = "<ip>"
	emailPlaceholder  = "<email>"
	secretPlaceholder = "<redacted>"

	// minAccountNameLen: a two-letter name appears inside ordinary words.
	minAccountNameLen = 3
)

// placeholderWords are the account names the literal pass refuses: the
// placeholders' own words, and the product's (issue #940).
var placeholderWords = map[string]bool{"user": true, "ip": true, "email": true, "redacted": true, "veaf": true, "dcs": true}

var (
	homeDir = regexp.MustCompile(`(?i)((?:[A-Za-z]:[\\/])?(?:Users|home|Documents and Settings)[\\/])([^\\/\r\n]+)`)

	urlCredentials = guarded{re: regexp.MustCompile(`://([^` + pyS + `/:@]{1,64}:[^` + pyS + `/@]{1,128})@`)}

	email = guarded{
		re:     regexp.MustCompile(`([` + pyW + `.+-]+@[` + pyW + `-]+(?:\.[` + pyW + `-]+)+)(?:[^` + pyW + `-]|$)`),
		refuse: prevIn(func(r rune) bool { return isWord(r) || r == '.' }),
	}

	labelledSecret = guarded{
		re: regexp.MustCompile(`(?i)((` +
			`["']?(?:[A-Za-z0-9]+[_-])*` +
			`(?:token|password|passwd|pwd|passphrase|secret|api[_-]?key|apikey|authorization|auth|credentials?|session|cookie|private[_-]?key|access[_-]?key)` +
			`(?:[_-][A-Za-z0-9]+)*["']?[` + pyS + `]*[:=][` + pyS + `]*)` +
			`(?:(?:bearer|basic|token|digest)[` + pyS + `]+)?` +
			`(?:"[^"\r\n]*"|'[^'\r\n]*'|[^` + pyS + `,;)\]}\r\n]+))`),
		refuse: prevIn(func(r rune) bool { return isWord(r) || r == '-' }),
	}
	// knownToken holds one group per shape; the ones the Python opens with \b
	// are refused after a word character, AWS's closes with \b too.
	knownToken = guarded{
		re: regexp.MustCompile(`` +
			`(gh[pousr]_[A-Za-z0-9]{16,})` +
			`|(github_pat_[A-Za-z0-9_]{20,})` +
			`|(xox[abposr]-[A-Za-z0-9-]{10,})` +
			`|(sk-(?:proj-|ant-)?[A-Za-z0-9_-]{16,})` +
			`|((?:AKIA|ASIA)[0-9A-Z]{16})(?:[^` + pyW + `]|$)` +
			`|(AIza[0-9A-Za-z_-]{35,})` +
			`|(eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,})` +
			`|(https://discord(?:app)?\.com/api/webhooks/[` + pyD + `]+/[A-Za-z0-9_-]+)` +
			`|(https://hooks\.slack\.com/services/[A-Za-z0-9/_+-]+)` +
			`|(-----BEGIN [A-Z ]*PRIVATE KEY-----)`),
		refuse: func(s string, at, group int) bool {
			if group > 7 {
				return false
			}
			r, ok := before(s, at)
			return ok && isWord(r)
		},
	}

	octet = `(?:25[0-5]|2[0-4][` + pyD + `]|1[` + pyD + `][` + pyD + `]|[1-9]?[` + pyD + `])`
	ipv4  = guarded{
		re: regexp.MustCompile(`(` + octet + `(?:\.` + octet + `){3})(?:[^` + pyW + `.]|$)`),
		refuse: func(s string, at, _ int) bool {
			r, ok := before(s, at)
			if ok && (isWord(r) || r == '.') {
				return true
			}
			// `DCS/2.9.10.1`: a dotted quad behind a letter and a slash is a version.
			if ok && r == '/' {
				if p, ok := before(s, at-1); ok && (p >= 'A' && p <= 'Z' || p >= 'a' && p <= 'z') {
					return true
				}
			}
			return false
		},
	}
	hextet = `[A-Fa-f0-9]{1,4}`
	ipv6   = guarded{
		re: regexp.MustCompile(`((?:` +
			hextet + `(?::` + hextet + `){7}` +
			`|(?:` + hextet + `:){1,7}:(?:` + hextet + `(?::` + hextet + `){0,6})?` +
			`|::` + hextet + `(?::` + hextet + `){0,7}` +
			`)(?:%[A-Za-z0-9._-]+)?)(?:[^` + pyW + `:.]|$)`),
		refuse: prevIn(func(r rune) bool { return isWord(r) || r == ':' || r == '.' }),
	}
)

// ipKeep are addresses that say nothing about anyone and help a diagnosis.
var ipKeep = map[string]bool{"0.0.0.0": true, "255.255.255.255": true, "::1": true, "::": true}

// Redactor redacts for one account: the names it is known by are replaced wherever they appear.
type Redactor struct {
	accounts []guarded
}

// NewRedactor builds the redactor of the given account names, the ones too
// short or too placeholder-like dropped, the longest applied first.
func NewRedactor(names ...string) *Redactor {
	seen := map[string]bool{}
	var kept []string
	for _, n := range names {
		if n == "" || runeLen(n) < minAccountNameLen || placeholderWords[strings.ToLower(n)] || seen[n] {
			continue
		}
		seen[n] = true
		kept = append(kept, n)
	}
	sort.SliceStable(kept, func(i, j int) bool {
		if a, b := runeLen(kept[i]), runeLen(kept[j]); a != b {
			return a > b
		}
		return kept[i] < kept[j]
	})
	r := &Redactor{}
	for _, n := range kept {
		r.accounts = append(r.accounts, guarded{
			re:     regexp.MustCompile(`(?i)(` + regexp.QuoteMeta(n) + `)(?:[^<>` + pyW + `]|$)`),
			refuse: prevIn(func(c rune) bool { return c == '<' || isWord(c) }),
		})
	}
	return r
}

var (
	machineOnce     sync.Once
	machineRedactor *Redactor
)

// MachineRedactor is the redactor of the account running the viewer: the
// name of its home folder and its login, as the Python reads them
// (`Path.home().name`, `getpass.getuser()`).
func MachineRedactor() *Redactor {
	machineOnce.Do(func() {
		var names []string
		if home, err := os.UserHomeDir(); err == nil {
			names = append(names, filepath.Base(home))
		}
		for _, env := range []string{"LOGNAME", "USER", "LNAME", "USERNAME"} {
			if v := os.Getenv(env); v != "" {
				names = append(names, v)
				break
			}
		}
		machineRedactor = NewRedactor(names...)
	})
	return machineRedactor
}

// Redact replaces account names, e-mail addresses, credentials and routable
// addresses, in the Python's order: a later rule must not chew through what an
// earlier one wrote.
func (r *Redactor) Redact(text string) string {
	if text == "" {
		return text
	}
	text = urlCredentials.replace(text, func(int, []string) string { return secretPlaceholder })
	text = homeDir.ReplaceAllString(text, "${1}"+userPlaceholder)
	text = email.replace(text, func(int, []string) string { return emailPlaceholder })
	text = labelledSecret.replace(text, func(_ int, m []string) string { return m[2] + secretPlaceholder })
	text = knownToken.replace(text, func(int, []string) string { return secretPlaceholder })
	for _, a := range r.accounts {
		text = a.replace(text, func(int, []string) string { return userPlaceholder })
	}
	ip := func(_ int, m []string) string {
		if s := m[0]; strings.HasPrefix(s, "127.") || ipKeep[s] {
			return s
		}
		return ipPlaceholder
	}
	text = ipv4.replace(text, ip)
	return ipv6.replace(text, ip)
}
