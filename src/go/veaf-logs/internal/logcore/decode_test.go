package logcore

import (
	"encoding/hex"
	"testing"
)

// Python's bytes.decode("utf-8", "replace") replaces each maximal subpart of an
// ill-formed sequence with one U+FFFD: a truncated multi-byte sequence is one
// replacement, not one per byte. Values measured on the Python, 2026-10-24.
func TestDecodeReplacesLikePython(t *testing.T) {
	for in, want := range map[string]string{
		"e28241":       "\ufffdA",
		"fffe":         "\ufffd\ufffd",
		"e282":         "\ufffd",
		"f09f98":       "\ufffd",
		"f09f4198":     "\ufffdA\ufffd",
		"eda080":       "\ufffd\ufffd\ufffd",
		"e08080":       "\ufffd\ufffd\ufffd",
		"c0af":         "\ufffd\ufffd",
		"f4908080":     "\ufffd\ufffd\ufffd\ufffd",
		"f18080e282ac": "\ufffd€",
		"618062":       "a\ufffdb",
		"c3":           "\ufffd",
		"f580":         "\ufffd\ufffd",
	} {
		b, _ := hex.DecodeString(in)
		if got := toValidUTF8(b); got != want {
			t.Errorf("%s: got %+q, want %+q", in, got, want)
		}
	}
}
