// Package apilog reads the logs of a DCS server through DCSServerBot's RestAPI
// (FEAT-VEAF-LOGS-REST-API): the HTTP half of logcore.APISource, and the
// discovery of what a server's API has to read. It only reads.
package apilog

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/sshlog"
)

// requestTimeout bounds one request: a read is at most 16 MiB scanned and 1 MiB returned.
const requestTimeout = 30 * time.Second

// ErrNoLogRoutes: the API answers but has no log routes (a bot older than
// them, or one without `api_key`, which they need).
var ErrNoLogRoutes = fmt.Errorf("no log routes on this RestAPI: %w", logcore.ErrAPIUnknownLog)

// Client is the RestAPI of one server, with its key.
type Client struct {
	base string
	key  string
	http *http.Client
}

// String and GoString keep the key out of anything printed.
func (c *Client) String() string   { return "apilog.Client(" + c.base + ")" }
func (c *Client) GoString() string { return c.String() }

// Open reads the key and prepares the client; it touches no network.
func Open(a *sshlog.API) (*Client, error) {
	data, err := os.ReadFile(a.KeyFile)
	if err != nil {
		return nil, fmt.Errorf("api_key_file: %w", err)
	}
	key := strings.TrimSpace(string(data))
	if key == "" {
		return nil, fmt.Errorf("api_key_file %s is empty", a.KeyFile)
	}
	if strings.ContainsFunc(key, func(r rune) bool { return r < ' ' || r == 0x7f }) {
		// Not a key an HTTP header can carry: said here, not as an unreachable server.
		return nil, fmt.Errorf("api_key_file %s: expected the key alone, on one line", a.KeyFile)
	}
	return &Client{base: a.URL, key: key, http: &http.Client{Timeout: requestTimeout}}, nil
}

// get asks a route and decodes its JSON answer into out; failures are
// classified as logcore's errors, with the server's own words.
func (c *Client) get(path string, q url.Values, out any) error {
	req, err := http.NewRequest(http.MethodGet, c.base+path+"?"+q.Encode(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("X-API-Key", c.key)
	resp, err := c.http.Do(req)
	if err != nil {
		var ue *url.Error
		if errors.As(err, &ue) {
			err = ue.Err // the URL, with its query, is not worth repeating
		}
		return fmt.Errorf("%s: %v: %w", c.base, err, logcore.ErrUnavailable)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("%s: %v: %w", c.base, err, logcore.ErrUnavailable)
	}
	if resp.StatusCode != http.StatusOK {
		return classify(resp.StatusCode, detail(body), q.Has("cursor"))
	}
	if err := json.Unmarshal(body, out); err != nil {
		return fmt.Errorf("%s%s: unexpected answer: %v", c.base, path, err)
	}
	return nil
}

// detail is FastAPI's `detail`: a sentence, or a list for a validation error.
func detail(body []byte) string {
	var d struct {
		Detail json.RawMessage `json:"detail"`
	}
	if json.Unmarshal(body, &d) != nil || len(d.Detail) == 0 {
		return strings.TrimSpace(string(body))
	}
	var s string
	if json.Unmarshal(d.Detail, &s) == nil {
		return s
	}
	return string(d.Detail)
}

// classify turns an HTTP error into what the source does about it. The 404s
// differ only by their text: the bot says which.
func classify(status int, detail string, cursor bool) error {
	var kind error
	switch {
	case status == http.StatusForbidden && strings.Contains(detail, "not allowed to read"):
		return fmt.Errorf("HTTP %d: %s", status, detail) // the file's rights on the server, not the key
	case status == http.StatusUnauthorized || status == http.StatusForbidden:
		kind = logcore.ErrAPIAuth
	case status == http.StatusNotFound && detail == "Not Found":
		kind = ErrNoLogRoutes // FastAPI's own answer to a route it does not have
	case status == http.StatusNotFound && strings.HasPrefix(detail, "No log file yet"):
		kind = logcore.ErrRemoteFileMissing
	case status == http.StatusNotFound && strings.Contains(detail, "disappeared"):
		kind = logcore.ErrUnavailable // rotated while read: the next poll finds it
	case status == http.StatusNotFound:
		kind = logcore.ErrAPIUnknownLog
	case status == http.StatusBadRequest && cursor && strings.Contains(strings.ToLower(detail), "cursor"):
		kind = logcore.ErrCursorRefused
	case status == http.StatusNotImplemented:
		kind = logcore.ErrAPIOtherNode
	case status >= 500:
		kind = logcore.ErrUnavailable
	default:
		return fmt.Errorf("HTTP %d: %s", status, detail)
	}
	return fmt.Errorf("HTTP %d: %s: %w", status, detail, kind)
}

// Log is the reader of one log, for logcore.APISource.
func (c *Client) Log(target sshlog.APILog) logcore.APIClient { return reader{c, target} }

type reader struct {
	c      *Client
	target sshlog.APILog
}

func (r reader) Read(q logcore.APIQuery) (logcore.APIPage, error) {
	v := values(r.target)
	if q.File != "" {
		v.Set("file", q.File)
	}
	if q.Cursor != "" {
		v.Set("cursor", q.Cursor)
	}
	v.Set("tail", strconv.FormatBool(q.Tail))
	v.Set("lines", strconv.Itoa(q.Lines))
	var page logcore.APIPage
	err := r.c.get(route(r.target, "log"), v, &page)
	return page, err
}

func route(t sshlog.APILog, what string) string {
	if t.Instance != "" {
		return "/instance/" + what
	}
	return "/node/" + what
}

// values names the log: the server, or the node (none: the API's own).
func values(t sshlog.APILog) url.Values {
	v := url.Values{}
	switch {
	case t.Instance != "":
		v.Set("server_name", t.Instance)
	case t.Node != "":
		v.Set("node_name", t.Node)
	}
	return v
}

// File is one file of a log, as the API lists it.
type File struct {
	Name     string    `json:"name"`
	Size     int64     `json:"size"`
	Modified time.Time `json:"modified"`
	Live     bool      `json:"live"`
}

// Files lists the files of a log, newest first.
func (c *Client) Files(target sshlog.APILog) ([]File, error) {
	var answer struct {
		Files []File `json:"files"`
	}
	err := c.get(route(target, "logs"), values(target), &answer)
	return answer.Files, err
}

// Log of a server, by the name the window shows.
type Log struct {
	Name   string
	Target sshlog.APILog
}

// Discover lists a server's logs: its `logs:` as written, else the servers the
// API knows and the bot log of the API's node. With `logs:`, c may be nil.
func Discover(s sshlog.Server, c *Client) ([]Log, error) {
	var out []Log
	if s.API.Logs != nil {
		for _, name := range s.Instances() {
			out = append(out, Log{name, s.API.Logs[name]})
		}
		return out, nil
	}
	var servers []struct {
		Name string `json:"name"`
	}
	if err := c.get("/servers", url.Values{}, &servers); err != nil {
		return nil, err
	}
	for _, sv := range servers {
		out = append(out, Log{sv.Name, sshlog.APILog{Instance: sv.Name}})
	}
	// The bot log answers only when the log routes exist: a bot without them is said now.
	if _, err := c.Files(sshlog.APILog{}); err != nil {
		return nil, err
	}
	return append(out, Log{sshlog.BotLog, sshlog.APILog{}}), nil
}
