package apilog

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

const testKey = "s3cr3t-k3y-n0t-t0-l3ak"

// fakeBot is the RestAPI of a DCSServerBot with the log routes, behind a prefix.
type fakeBot struct {
	*httptest.Server
	requests []*http.Request
	// answer, when set, replaces the canned answers.
	answer func(w http.ResponseWriter, r *http.Request) bool
}

func startBot(t *testing.T) *fakeBot {
	t.Helper()
	b := &fakeBot{}
	b.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b.requests = append(b.requests, r)
		if r.Header.Get("X-API-Key") != testKey {
			fail(w, http.StatusForbidden, "Invalid API Key")
			return
		}
		if b.answer != nil && b.answer(w, r) {
			return
		}
		switch r.URL.Path {
		case "/api/servers":
			json.NewEncoder(w).Encode([]map[string]any{{"name": "VEAF Private 1", "password": "pw"}, {"name": "VEAF Public 1"}})
		case "/api/node/logs":
			json.NewEncoder(w).Encode(map[string]any{"log": "bot", "node": "dcs-veaf-org", "files": []map[string]any{
				{"name": "dcssb-dcs-veaf-org.log", "size": 4677, "modified": "2026-10-26T12:34:00Z", "live": true}}})
		case "/api/instance/logs":
			json.NewEncoder(w).Encode(map[string]any{"log": "dcs", "node": "n", "server_name": r.URL.Query().Get("server_name"), "files": []map[string]any{
				{"name": "dcs.log", "size": 183554, "modified": "2026-10-18T10:15:02Z", "live": true},
				{"name": "dcs-20261018-100212.log", "size": 920114, "modified": "2026-10-18T10:02:11Z", "live": false}}})
		case "/api/instance/log", "/api/node/log":
			json.NewEncoder(w).Encode(map[string]any{"file": "dcs.log", "utc": true, "cursor": "c-next", "rotated": true, "gap": false,
				"new_file_at": 1, "more": false, "scanned_bytes": 10, "lines": []map[string]string{
					{"time": "2026-10-26 10:00:00.000", "level": "INFO", "text": "SCRIPTING (Main): a"},
					{"time": "2026-10-26 10:00:01.000", "level": "INFO", "text": "SCRIPTING (Main): b"}}})
		default:
			fail(w, http.StatusNotFound, "Not Found")
		}
	}))
	t.Cleanup(b.Close)
	return b
}

func fail(w http.ResponseWriter, status int, detail string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"detail": detail})
}

func (b *fakeBot) server(t *testing.T, key string, logs map[string]sshlog.APILog) sshlog.Server {
	t.Helper()
	path := filepath.Join(t.TempDir(), "key")
	if err := os.WriteFile(path, []byte(key+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return sshlog.Server{Name: "veaf-api", API: &sshlog.API{URL: b.URL + "/api", KeyFile: path, Logs: logs}}
}

func (b *fakeBot) open(t *testing.T, key string) *Client {
	t.Helper()
	c, err := Open(b.server(t, key, nil).API)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestReadSendsTheQueryAndDecodesTheAnswer(t *testing.T) {
	b := startBot(t)
	c := b.open(t, testKey)
	page, err := c.Log(sshlog.APILog{Instance: "VEAF Private 1"}).Read(logcore.APIQuery{File: "dcs-1.log", Lines: 2000, Cursor: "c-prev"})
	if err != nil {
		t.Fatal(err)
	}
	q := b.requests[0].URL
	if q.Path != "/api/instance/log" || q.Query().Get("server_name") != "VEAF Private 1" || q.Query().Get("file") != "dcs-1.log" ||
		q.Query().Get("cursor") != "c-prev" || q.Query().Get("lines") != "2000" || q.Query().Get("tail") != "false" {
		t.Fatalf("query = %s", q)
	}
	if len(page.Entries) != 2 || page.Entries[1].Text != "SCRIPTING (Main): b" || page.Cursor != "c-next" || !page.Rotated ||
		page.NewFileAt == nil || *page.NewFileAt != 1 {
		t.Fatalf("page = %+v", page)
	}
	c.Log(sshlog.APILog{Node: "other"}).Read(logcore.APIQuery{Tail: true, Lines: 2000})
	q = b.requests[1].URL
	if q.Path != "/api/node/log" || q.Query().Get("node_name") != "other" || q.Query().Get("tail") != "true" || q.Query().Has("cursor") {
		t.Fatalf("bot query = %s", q)
	}
	c.Log(sshlog.APILog{}).Read(logcore.APIQuery{Tail: true, Lines: 2000})
	if b.requests[2].URL.Query().Has("node_name") {
		t.Fatal("the API's own node is asked by leaving node_name out")
	}
}

func TestErrorsAreClassified(t *testing.T) {
	cases := []struct {
		status int
		detail string
		cursor bool
		want   error
	}{
		{404, "No log file yet (looked for 'dcs.log').", false, logcore.ErrRemoteFileMissing},
		{404, "Server 'gone' not found.", false, logcore.ErrAPIUnknownLog},
		{404, "No log file 'dcs-1.log' (list the files to get their names).", false, logcore.ErrAPIUnknownLog},
		{404, "The log file disappeared while it was read, try again.", false, logcore.ErrUnavailable},
		{400, "Invalid cursor (unknown cursor version).", true, logcore.ErrCursorRefused},
		{400, "This cursor belongs to another log.", true, logcore.ErrCursorRefused},
		{401, "Not authenticated", false, logcore.ErrAPIAuth},
		{403, "Invalid API Key", false, logcore.ErrAPIAuth},
		{501, "Server 'x' runs on node 'y'", false, logcore.ErrAPIOtherNode},
		{503, "Node inactive", false, logcore.ErrUnavailable},
		{504, "Node does not answer", false, logcore.ErrUnavailable},
		{500, "Failed to read the log: boom", false, logcore.ErrUnavailable},
	}
	for _, c := range cases {
		t.Run(fmt.Sprint(c.status, " ", c.detail), func(t *testing.T) {
			b := startBot(t)
			b.answer = func(w http.ResponseWriter, _ *http.Request) bool { fail(w, c.status, c.detail); return true }
			q := logcore.APIQuery{Tail: true, Lines: 10}
			if c.cursor {
				q = logcore.APIQuery{Cursor: "c", Lines: 10}
			}
			_, err := b.open(t, testKey).Log(sshlog.APILog{Instance: "x"}).Read(q)
			if !errors.Is(err, c.want) {
				t.Fatalf("err = %v, want %v", err, c.want)
			}
			if !strings.Contains(err.Error(), c.detail) {
				t.Fatalf("%v does not carry the server's detail", err)
			}
		})
	}
	t.Run("403 on the file's rights is not the key's", func(t *testing.T) {
		b := startBot(t)
		b.answer = func(w http.ResponseWriter, _ *http.Request) bool {
			fail(w, 403, "The bot is not allowed to read this log file.")
			return true
		}
		_, err := b.open(t, testKey).Log(sshlog.APILog{Instance: "x"}).Read(logcore.APIQuery{Tail: true, Lines: 10})
		if err == nil || errors.Is(err, logcore.ErrAPIAuth) {
			t.Fatalf("err = %v", err)
		}
	})
	t.Run("400 without a cursor is the request's fault, not the cursor's", func(t *testing.T) {
		b := startBot(t)
		b.answer = func(w http.ResponseWriter, _ *http.Request) bool { fail(w, 400, "Invalid level 'x'"); return true }
		_, err := b.open(t, testKey).Log(sshlog.APILog{Instance: "x"}).Read(logcore.APIQuery{Tail: true, Lines: 10})
		if err == nil || errors.Is(err, logcore.ErrCursorRefused) || errors.Is(err, logcore.ErrUnavailable) {
			t.Fatalf("err = %v", err)
		}
	})
}

func TestNetworkFailureIsUnavailable(t *testing.T) {
	b := startBot(t)
	c := b.open(t, testKey)
	b.Close()
	if _, err := c.Log(sshlog.APILog{Instance: "x"}).Read(logcore.APIQuery{Tail: true, Lines: 10}); !errors.Is(err, logcore.ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
}

func TestDiscoverListsTheServersAndTheBotLog(t *testing.T) {
	b := startBot(t)
	s := b.server(t, testKey, nil)
	c, _ := Open(s.API)
	logs, err := Discover(s, c)
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, l := range logs {
		names = append(names, l.Name)
	}
	if strings.Join(names, ",") != "VEAF Private 1,VEAF Public 1,bot" || logs[2].Target != (sshlog.APILog{}) || logs[0].Target.Instance != "VEAF Private 1" {
		t.Fatalf("logs = %+v", logs)
	}
}

func TestDiscoverWithLogsAsksNothing(t *testing.T) {
	b := startBot(t)
	s, _ := sshlog.ParseServers([]byte("servers:\n  a:\n    api: {url: 'http://127.0.0.1:1', api_key_file: k}\n    logs:\n      p1: {instance: VEAF Private 1}\n      bot: {node: n}\n"))
	logs, err := Discover(s[0], nil)
	if err != nil || len(logs) != 2 || logs[0].Name != "p1" || logs[0].Target.Instance != "VEAF Private 1" || logs[1].Target.Node != "n" {
		t.Fatalf("logs = %+v, %v", logs, err)
	}
	if len(b.requests) != 0 {
		t.Fatal("`logs:` says what there is: no request")
	}
}

func TestDiscoverRefusedSaysSo(t *testing.T) {
	b := startBot(t)
	s := b.server(t, "wrong-key", nil)
	c, _ := Open(s.API)
	if _, err := Discover(s, c); !errors.Is(err, logcore.ErrAPIAuth) {
		t.Fatalf("err = %v", err)
	}
}

func TestDiscoverOnABotWithoutLogRoutes(t *testing.T) {
	b := startBot(t)
	b.answer = func(w http.ResponseWriter, r *http.Request) bool {
		if strings.HasPrefix(r.URL.Path, "/api/node/") {
			fail(w, 404, "Not Found")
			return true
		}
		return false
	}
	s := b.server(t, testKey, nil)
	c, _ := Open(s.API)
	if _, err := Discover(s, c); !errors.Is(err, ErrNoLogRoutes) {
		t.Fatalf("err = %v", err)
	}
}

func TestFiles(t *testing.T) {
	b := startBot(t)
	files, err := b.open(t, testKey).Files(sshlog.APILog{Instance: "VEAF Private 1"})
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 2 || !files[0].Live || files[1].Name != "dcs-20261018-100212.log" || files[1].Size != 920114 || files[1].Modified.Hour() != 10 {
		t.Fatalf("files = %+v", files)
	}
	if q := b.requests[0].URL; q.Path != "/api/instance/logs" || q.Query().Get("server_name") != "VEAF Private 1" {
		t.Fatalf("query = %s", q)
	}
}

func TestTheKeyNeverShows(t *testing.T) {
	b := startBot(t)
	s := b.server(t, testKey, nil)
	c, _ := Open(s.API)
	b.answer = func(w http.ResponseWriter, _ *http.Request) bool { fail(w, 500, "boom"); return true }
	_, err := c.Log(sshlog.APILog{Instance: "x"}).Read(logcore.APIQuery{Tail: true, Lines: 10})
	_, derr := Discover(s, c)
	b.Close()
	_, nerr := c.Files(sshlog.APILog{Instance: "x"})
	for _, e := range []error{err, derr, nerr} {
		if e == nil || strings.Contains(e.Error(), testKey) {
			t.Fatalf("error %v", e)
		}
	}
	if strings.Contains(fmt.Sprintf("%+v %#v", c, c), testKey) {
		t.Fatal("printing the client shows the key")
	}
}

func TestOpenNeedsAReadableKeyFile(t *testing.T) {
	if _, err := Open(&sshlog.API{URL: "https://h", KeyFile: filepath.Join(t.TempDir(), "none")}); err == nil {
		t.Fatal("a missing key file must fail")
	}
	empty := filepath.Join(t.TempDir(), "empty")
	os.WriteFile(empty, []byte("\n"), 0o600)
	if _, err := Open(&sshlog.API{URL: "https://h", KeyFile: empty}); err == nil {
		t.Fatal("an empty key file must fail")
	}
	several := filepath.Join(t.TempDir(), "several")
	os.WriteFile(several, []byte("servers:\n  a: b\n"), 0o600)
	if _, err := Open(&sshlog.API{URL: "https://h", KeyFile: several}); err == nil || !strings.Contains(err.Error(), "one line") {
		t.Fatalf("a key file of several lines: %v", err)
	}
}

func TestAPISourceOverHTTP(t *testing.T) {
	b := startBot(t)
	b.answer = func(w http.ResponseWriter, r *http.Request) bool {
		if r.URL.Query().Get("cursor") != "" {
			return false
		}
		json.NewEncoder(w).Encode(map[string]any{"cursor": "c1", "more": true, "lines": []map[string]string{
			{"time": "2026-10-26 09:00:00.000", "level": "ERROR", "text": "SCRIPTING (Main): first\nstack traceback:"}}})
		return true
	}
	src, err := logcore.NewAPISource(b.open(t, testKey).Log(sshlog.APILog{Instance: "VEAF Private 1"}), logcore.APISourceOptions{})
	if err != nil {
		t.Fatal(err)
	}
	defer src.Close()
	if err := src.Open(); err != nil {
		t.Fatal(err)
	}
	rotated, err := src.Fetch(0)
	if err != nil || !rotated {
		t.Fatalf("rotated=%v err=%v", rotated, err)
	}
	if got := string(src.Buffer().Slice(0, src.Buffer().Size())); got != "2026-10-26 10:00:01.000 INFO SCRIPTING (Main): b\n" {
		t.Fatalf("mirror = %q", got)
	}
}
