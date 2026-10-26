package analysis

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// The online layer (`veaf_logs.worker_client`): the excerpt and the catalogue
// matches posted to the VEAF Worker, which holds the model's key — the tool
// holds none. Nothing raised here is fatal: the catalogue answer stands alone.

const (
	// DefaultEndpoint is the production Worker's route.
	DefaultEndpoint = "https://veaf-docs-chatbot.veaf.workers.dev/analyze"

	workerTimeout   = 45 * time.Second
	unreachable     = "Analyse en ligne indisponible (pas de réponse du service). Le catalogue ci-dessus reste valable."
	nothingReturned = "Le service n'a rien renvoyé. Le catalogue ci-dessus reste valable."
)

// AnalyseExcerpt asks the Worker to put an excerpt in context and returns what
// it said; an error carries a message meant to be shown as it stands.
func AnalyseExcerpt(endpoint, excerpt string, matches []WorkerMatch, question, lang string) (string, error) {
	if lang != "en" {
		lang = "fr"
	}
	if matches == nil {
		matches = []WorkerMatch{}
	}
	body, err := json.Marshal(map[string]any{"lang": lang, "excerpt": excerpt, "matches": matches, "question": question})
	if err != nil {
		return "", err
	}
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return "", errors.New(unreachable)
	}
	req.Header.Set("X-VEAF-Client", "logs")
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: workerTimeout}).Do(req)
	if err != nil {
		return "", errors.New(unreachable)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("Analyse en ligne indisponible (code %d).", resp.StatusCode)
	}
	var out strings.Builder
	sc := bufio.NewScanner(resp.Body)
	sc.Buffer(make([]byte, 64*1024), 8<<20)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		payload := strings.TrimSpace(line[len("data:"):])
		if payload == "" || payload == "[DONE]" {
			continue
		}
		var data map[string]any
		if json.Unmarshal([]byte(payload), &data) != nil {
			continue // a fragment that cannot be read is not a reason to lose the others
		}
		if e := data["error"]; truthy(e) {
			return "", errors.New(fmt.Sprint(e))
		}
		if text, ok := data["text"].(string); ok {
			out.WriteString(text)
		}
	}
	if err := sc.Err(); err != nil {
		return "", errors.New(unreachable)
	}
	return out.String(), nil
}

// truthy is Python's bool() of a decoded JSON value.
func truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case string:
		return x != ""
	case float64:
		return x != 0
	case []any:
		return len(x) > 0
	case map[string]any:
		return len(x) > 0
	}
	return true
}

// Online runs the online layer on an analysis: the answer, or why there is none.
func Online(a Analysis, endpoint, question string) Analysis {
	commentary, err := AnalyseExcerpt(endpoint, a.Excerpt.Text(), ToWorkerMatches(a.Matches), question, "fr")
	switch {
	case err != nil:
		return a.WithModel("", err.Error())
	case pyStrip(commentary) == "":
		return a.WithModel("", nothingReturned)
	}
	return a.WithModel(pyStrip(commentary), "")
}
